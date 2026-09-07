import 'dart:convert';
import 'dart:typed_data';

/// 解析 Palm 数据库外壳(PalmDB header + section 表),MOBI/AZW 都包在这层。
///
/// 布局(Palm 格式,全部大端):
///   [0, 78)    PalmDB 头(前 32 字节=数据库名,0x3C 起 8 字节 ident)
///   [78, ...)  每 section 8 字节:offset(u32) + attr(u32);末尾隐式接文件总长
class PalmContainer {
  PalmContainer._(this.bytes, this.ident, this.sectionOffsets);

  final Uint8List bytes;

  /// 'BOOKMOBI'(带 MOBI 头的书)、'TEXtREAd'(裸 PalmDOC)等。
  final String ident;

  /// sectionOffsets[i] = 第 i 个 section 的起始偏移,末尾补文件总长,
  /// 故 section i 的区间为 [offsets[i], offsets[i+1])。
  final List<int> sectionOffsets;

  int get sectionCount => sectionOffsets.length - 1;

  static PalmContainer parse(Uint8List bytes) {
    if (bytes.length < 78) {
      throw const MobiFormatException('file too small for a Palm database');
    }
    final identBytes = bytes.sublist(0x3C, 0x3C + 8);
    final ident = latin1.decode(identBytes).trim();
    if (ident != 'BOOKMOBI' && ident != 'TEXtREAd') {
      throw MobiFormatException(
        'not a MOBI/Palm database (ident "$ident")',
      );
    }
    final count = _u16(bytes, 76);
    if (78 + count * 8 > bytes.length) {
      throw MobiFormatException('section table out of range');
    }
    final offsets = <int>[
      for (var i = 0; i < count; i++) _u32(bytes, 78 + i * 8),
      bytes.length,
    ];
    return PalmContainer._(bytes, ident, offsets);
  }

  Uint8List loadSection(int index) {
    if (index < 0 || index >= sectionCount) {
      throw RangeError.range(index, 0, sectionCount - 1, 'section');
    }
    final start = sectionOffsets[index];
    final end = sectionOffsets[index + 1];
    return bytes.sublist(start, end);
  }
}

/// 解析 MOBI 头(section 0)与 EXTH 元数据。
///
/// section 0 结构:PalmDOC 头(前 16 字节)内嵌 MOBI 头('MOBI' magic 在偏移 16)。
/// EXTH 紧随 MOBI 头之后(exth_flags 低位为 1 时存在)。
class MobiHeader {
  MobiHeader._({
    required this.compression,
    required this.textRecords,
    required this.codepage,
    required this.version,
    required this.headerLength,
    required this.firstNontext,
    required this.exthFlags,
    required this.exth,
  });

  /// 0=无压缩 2=PalmDOC 0x4448=Huffman(KF8/AZW3)。
  final int compression;
  final int textRecords;
  final int codepage;
  final int version;

  /// MOBI 头长度(自 'MOBI' magic 起)。
  final int headerLength;
  final int firstNontext;
  final int exthFlags;
  final Map<int, List<int>> exth;

  bool get isHuffman => compression == 0x4448;

  /// EXTH 存在标志是 exth_flags 的 0x40 位(见 kindleunpack)。
  bool get hasExth => exthFlags & 0x40 != 0;

  String? get title => _exthText(503) ?? _exthText(3) ?? _exthText(14);
  List<String> get authors {
    final raw = _exthText(100);
    if (raw == null || raw.isEmpty) {
      return const <String>[];
    }
    return raw
        .split('\u0000')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
  }

  String? get language => _exthText(524);
  String? get asin => _exthText(113) ?? _exthText(504);
  String? get description => _exthText(103);

  String? _exthText(int type) {
    final data = exth[type];
    if (data == null) {
      return null;
    }
    return _decodeText(data, codepage).trim();
  }

  /// 从 section 0 解析 MOBI 头;若为裸 PalmDOC(ident==TEXtREAd)则按纯文本处理。
  static MobiHeader parse(PalmContainer container) {
    final section0 = container.loadSection(0);

    if (container.ident == 'TEXtREAd') {
      // 无 MOBI 头的裸 PalmDOC:没有 EXTH/元数据,正文直接按文档读。
      return MobiHeader._(
        compression: _u16(section0, 0x00),
        textRecords: _u16(section0, 0x08),
        codepage: _u32(section0, 0x1C),
        version: 0,
        headerLength: 0,
        firstNontext: 1 + _u16(section0, 0x08),
        exthFlags: 0,
        exth: const <int, List<int>>{},
      );
    }

    if (section0.length < 24 || _asciiAt(section0, 16, 4) != 'MOBI') {
      throw const MobiFormatException('missing MOBI magic');
    }
    final headerLength = _u32(section0, 0x14);
    final version = _u32(section0, 0x24);
    final firstNontext = _u32(section0, 0x50);
    final exthFlags = _u32(section0, 0x80);

    Map<int, List<int>> exth = const <int, List<int>>{};
    if (exthFlags & 0x40 != 0) {
      // EXTH 紧跟 MOBI 头之后:起点 = 16(PalmDOC 头)+ headerLength。
      exth = _parseExth(section0, 16 + headerLength);
    }
    return MobiHeader._(
      compression: _u16(section0, 0x00),
      textRecords: _u16(section0, 0x08),
      codepage: _u32(section0, 0x1C),
      version: version,
      headerLength: headerLength,
      firstNontext: firstNontext,
      exthFlags: exthFlags,
      exth: exth,
    );
  }
}

/// EXTH 块:紧随 MOBI 头,`EXTH` magic + 长度 + 记录数,然后每条
/// type(u32) + length(u32) + payload。
Map<int, List<int>> _parseExth(Uint8List section0, int start) {
  if (start + 12 > section0.length || _asciiAt(section0, start, 4) != 'EXTH') {
    return const <int, List<int>>{};
  }
  final count = _u32(section0, start + 8);
  var cursor = start + 12;
  final result = <int, List<int>>{};
  for (var i = 0; i < count && cursor + 8 <= section0.length; i++) {
    final type = _u32(section0, cursor);
    final length = _u32(section0, cursor + 4);
    cursor += 8;
    if (length < 8 || cursor + (length - 8) > section0.length) {
      break;
    }
    result.putIfAbsent(type, () => <int>[]).addAll(
      section0.sublist(cursor, cursor + length - 8),
    );
    cursor += length - 8;
  }
  return result;
}

/// 字符编码按 MOBI codepage 映射(Dart 仅有 latin1/utf8,其余按 latin1 近似)。
String _decodeText(List<int> bytes, int codepage) {
  switch (codepage) {
    case 65001:
      return utf8.decode(bytes, allowMalformed: true);
    case 1252:
      // windows-1252 在 0x80..0x9F 与 latin1 不同,但正文多为可打印字符,
      // 先用 latin1 近似(老 mobi 多为 cp1252)。
      return latin1.decode(bytes);
    default:
      return latin1.decode(bytes);
  }
}

/// 读取 [offset] 起 [length] 字节的 ASCII 文本。
String _asciiAt(Uint8List data, int offset, int length) {
  if (offset < 0 || offset + length > data.length) {
    return '';
  }
  final sb = StringBuffer();
  for (var i = offset; i < offset + length; i++) {
    sb.writeCharCode(data[i]);
  }
  return sb.toString();
}

int _u16(Uint8List data, int offset) {
  return (data[offset] << 8) | data[offset + 1];
}

int _u32(Uint8List data, int offset) {
  return (data[offset] << 24) |
      (data[offset + 1] << 16) |
      (data[offset + 2] << 8) |
      data[offset + 3];
}

class MobiFormatException implements Exception {
  const MobiFormatException(this.message);

  final String message;

  @override
  String toString() => 'MobiFormatException: $message';
}
