import 'dart:typed_data';

import 'mobi_container.dart';

/// KF8/AZW3 的 HUFF/CDIC 解压(Huffman 压缩,compression==0x4448)。
///
/// 算法参考 KindleUnpack / kindle_unpack 的公开格式实现,**自研重写**:
/// - HUFF record:24 字节头(`HUFF` + len=0x18 + off1/off2),off1 处 256 项
///   快速查表(低 5 位 codeLen、bit7 terminal、高 24 位 maxCode),off2 处
///   32 对 (mincode,maxcode) 按码长索引,供非 terminal 慢路径。
/// - CDIC record:16 字节头(`CDIC` + len=0x10 + phrases + bits),后跟偏移
///   表与短语负载;多条 CDIC 累积填同一张字典。短语条目可能是"预解码"
///   (precoded)或本身仍为 HUFF 负载(首次使用时递归展开并缓存)。
/// - 解压:64 位滑动窗口位读,取码 → 查字典下标 → 输出;递归展开短语。
class MobiHuffCdic {
  MobiHuffCdic._(
    this._cache,
    this._cacheMax,
    this._minCode,
    this._maxCodeByLen,
    List<Uint8List> dict,
    List<bool> precoded,
  )   : _dict = dict,
        _precoded = precoded;

  // 256 项快表:每项打包 codeLen(低5)|terminal(bit7)|maxCode(高24 提升到32位)。
  final List<int> _cache; // raw u32,低 5 位 codeLen、bit7 terminal
  final List<int> _cacheMax; // 提升后的 32 位 maxCode
  final List<int> _minCode; // [33]
  final List<int> _maxCodeByLen; // [33]
  final List<Uint8List> _dict; // 短语表(下标即字典序)
  final List<bool> _precoded;
  final Set<int> _expanding = <int>{};

  int _codeLen(int v) => v & 0x1F;
  bool _terminal(int v) => (v & 0x80) != 0;

  /// 从 [container] 的 HUFF + CDIC section(s)构建解码器。
  /// [baseSection] 是 KF8 header 所在 section(组合 mobi 时非 0)。
  static MobiHuffCdic fromContainer(
    PalmContainer container,
    MobiHeader header, {
    int baseSection = 0,
  }) {
    if (!header.isHuffman || header.huffNum < 2) {
      throw const MobiFormatException('not a HUFF/CDIC compressed book');
    }
    final huffSection = baseSection + header.huffOffset;
    final huffBytes = container.loadSection(huffSection);
    final (cache, cacheMax, minCode, maxCodeByLen) = _parseHuff(huffBytes);

    // 第 1 个是 HUFF,其余全是 CDIC(累积填同一张字典)。
    final dict = <Uint8List>[];
    final precoded = <bool>[];
    for (var i = 1; i < header.huffNum; i++) {
      final cdicBytes = container.loadSection(huffSection + i);
      _parseCdic(cdicBytes, dict, precoded);
    }
    return MobiHuffCdic._(cache, cacheMax, minCode, maxCodeByLen, dict, precoded);
  }
  /// 解压一段正文记录。
  Uint8List decompress(Uint8List input) {
    final padded = Uint8List(input.length + 8);
    padded.setRange(0, input.length, input);
    final view = ByteData.sublistView(padded);

    var bitsLeft = input.length * 8;
    var pos = 0;
    var high = view.getUint32(0);
    var low = view.getUint32(4);
    var n = 32;
    final out = BytesBuilder(copy: false);

    while (true) {
      if (n <= 0) {
        pos += 4;
        high = low;
        low = view.getUint32(pos + 4);
        n += 32;
      }
      final int code;
      if (n == 32) {
        code = high;
      } else if (n == 0) {
        code = low;
      } else {
        code = ((high << (32 - n)) | (low >>> n)) & 0xFFFFFFFF;
      }

      final idx = code >>> 24;
      var codeLen = _codeLen(_cache[idx]);
      if (!_terminal(_cache[idx])) {
        while (code < _minCode[codeLen]) {
          codeLen++;
          if (codeLen > 32) {
            throw const MobiFormatException('HUFF codeword exceeds 32 bits');
          }
        }
      }
      final maxCode = _terminal(_cache[idx]) ? _cacheMax[idx] : _maxCodeByLen[codeLen];

      n -= codeLen;
      bitsLeft -= codeLen;
      if (bitsLeft < 0) {
        break;
      }

      final r = (maxCode - code) >>> (32 - codeLen);
      if (r < 0 || r >= _dict.length) {
        throw MobiFormatException('HUFF dict index $r out of range');
      }
      if (_precoded[r]) {
        out.add(_dict[r]);
      } else {
        if (!_expanding.add(r)) {
          throw MobiFormatException('cycle in HUFF dict entry $r');
        }
        final expanded = decompress(_dict[r]);
        _expanding.remove(r);
        _dict[r] = expanded;
        _precoded[r] = true;
        out.add(expanded);
      }
    }
    return out.toBytes();
  }

  static (List<int>, List<int>, List<int>, List<int>) _parseHuff(
    Uint8List rec,
  ) {
    if (rec.length < 24 || _ascii(rec, 0, 4) != 'HUFF') {
      throw const MobiFormatException('bad HUFF record');
    }
    final view = ByteData.sublistView(rec);
    if (view.getUint32(4) != 0x18) {
      throw const MobiFormatException('unsupported HUFF header len');
    }
    final off1 = view.getUint32(8);
    final off2 = view.getUint32(12);
    final cache = <int>[];
    final cacheMax = <int>[];
    for (var i = 0; i < 256; i++) {
      final v = view.getUint32(off1 + i * 4);
      final codeLen = v & 0x1F;
      if (codeLen == 0) {
        throw const MobiFormatException('HUFF cache codeLen 0');
      }
      final maxCode = (((v >> 8) + 1) << (32 - codeLen)) - 1;
      cache.add(v);
      cacheMax.add(maxCode & 0xFFFFFFFF);
    }
    final minCode = List<int>.filled(33, 0);
    final maxCodeByLen = List<int>.filled(33, 0);
    maxCodeByLen[0] = 0xFFFFFFFF;
    for (var i = 1; i <= 32; i++) {
      final minRaw = view.getUint32(off2 + (i - 1) * 8);
      final maxRaw = view.getUint32(off2 + (i - 1) * 8 + 4);
      minCode[i] = (minRaw << (32 - i)) & 0xFFFFFFFF;
      maxCodeByLen[i] = (((maxRaw + 1) << (32 - i)) - 1) & 0xFFFFFFFF;
    }
    return (cache, cacheMax, minCode, maxCodeByLen);
  }

  static void _parseCdic(
    Uint8List rec,
    List<Uint8List> dict,
    List<bool> precoded,
  ) {
    if (rec.length < 16 || _ascii(rec, 0, 4) != 'CDIC') {
      throw const MobiFormatException('bad CDIC record');
    }
    final view = ByteData.sublistView(rec);
    if (view.getUint32(4) != 0x10) {
      throw const MobiFormatException('unsupported CDIC header len');
    }
    final phrases = view.getUint32(8);
    final bits = view.getUint32(12);
    final maxEntries = (1 << bits).clamp(0, phrases - dict.length).toInt();
    for (var i = 0; i < maxEntries; i++) {
      final off = view.getUint16(16 + i * 2);
      final lengthAndFlag = view.getUint16(16 + off);
      final blen = lengthAndFlag & 0x7FFF;
      final pre = (lengthAndFlag & 0x8000) != 0;
      final start = 16 + off + 2;
      dict.add(Uint8List.sublistView(rec, start, start + blen));
      precoded.add(pre);
    }
  }

  static String _ascii(Uint8List data, int off, int len) {
    final sb = StringBuffer();
    for (var i = off; i < off + len; i++) {
      sb.writeCharCode(data[i]);
    }
    return sb.toString();
  }
}
