import 'dart:typed_data';

/// 正文记录解压。MOBI 压缩类型:1=无压缩,2=PalmDOC,0x4448=Huffman(KF8)。
Uint8List decompressRecord(int compression, Uint8List data) {
  switch (compression) {
    case 1:
      return data;
    case 2:
      return _palmdoc(data);
    case 0x4448:
      throw UnimplementedError(
        'Huffman (0x4448) decompression not implemented yet',
      );
    default:
      throw StateError(
        'unknown compression type 0x${compression.toRadixString(16)}',
      );
  }
}

/// PalmDOC LZ77 变体(逐字节流式解压)。
///
/// 控制字节分四类:
///   0x00, 0x09..0x7F : 字面字节
///   0x01..0x08       : 直接复制后续 N 字节
///   0x80..0xBF       : 2 字节回引。14 位(去 10 前缀)拆成
///                      11 位距离(1..2047,向前数)+ 3 位长度(实际 3..10)。
///                      逐字节复制,距离<长度时产生重复串(run-length)。
///   0xC0..0xFF       : 空格对:输出 0x20 + (c ^ 0x80)。
Uint8List _palmdoc(Uint8List input) {
  var capacity = input.length * 3 + 1024;
  var out = Uint8List(capacity);
  var w = 0;

  void ensure(int extra) {
    if (w + extra <= out.length) {
      return;
    }
    final grown = Uint8List((out.length + extra) * 2);
    grown.setRange(0, w, out);
    out = grown;
  }

  var p = 0;
  while (p < input.length) {
    final c = input[p];
    p += 1;
    if (c == 0 || (c >= 0x09 && c <= 0x7F)) {
      ensure(1);
      out[w++] = c;
    } else if (c >= 0x01 && c <= 0x08) {
      if (p + c > input.length) {
        break; // 截断的 literal run:容错跳出。
      }
      ensure(c);
      out.setRange(w, w + c, input, p);
      w += c;
      p += c;
    } else if (c >= 0x80 && c <= 0xBF) {
      if (p >= input.length) {
        break; // 截断的 backref:容错跳出。
      }
      final next = input[p];
      p += 1;
      final combined = ((c << 8) | next) & 0x3FFF;
      final distance = combined >> 3;
      final length = (combined & 0x07) + 3;
      if (distance == 0 || distance > w) {
        // 非法回引(损坏数据):填空格跳过,避免整本读不出。
        ensure(length);
        for (var i = 0; i < length; i++) {
          out[w++] = 0x20;
        }
        continue;
      }
      ensure(length);
      // 逐字节复制;distance<length 时刚写入的字节会作为后续源(run-length)。
      for (var i = 0; i < length; i++) {
        out[w] = out[w - distance];
        w += 1;
      }
    } else {
      // 0xC0..0xFF:空格对。
      ensure(2);
      out[w++] = 0x20;
      out[w++] = c ^ 0x80;
    }
  }
  return Uint8List.sublistView(out, 0, w);
}
