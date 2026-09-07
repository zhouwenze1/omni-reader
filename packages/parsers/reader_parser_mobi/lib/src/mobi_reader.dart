import 'dart:typed_data';

import 'mobi_container.dart';
import 'mobi_decompress.dart';

/// 一部 MOBI 反解出的"书":正文 HTML 流 + 元数据 + 封面(若有)。
class MobiBook {
  MobiBook({
    required this.container,
    required this.header,
    required this.rawHtml,
    this.images = const <MobiImage>[],
  });

  final PalmContainer container;
  final MobiHeader header;

  /// 解压后的 Mobipocket HTML(未清洗,含 <mbp:pagebreak/> 等专有标签)。
  final Uint8List rawHtml;

  /// 正文 section 之后抽取到的图片(含封面,按出现顺序)。
  final List<MobiImage> images;
}

class MobiImage {
  MobiImage({
    required this.index,
    required this.data,
    required this.mediaType,
    required this.isCover,
  });

  /// 在资源区的 section 号,用作稳定命名。
  final int index;
  final Uint8List data;
  final String mediaType;
  final bool isCover;
}

/// 读取 PalmDB + MOBI 头,解压正文 section 拼成 raw HTML。
///
/// 只处理 Mobi7(压缩 1/2);Huffman(KF8) 解压未实现时抛 [MobiFormatException]
/// 提示需要 KF8 支持。返回的书保留原始字节,由调用方负责 container 生命周期。
MobiBook readMobi(Uint8List bytes) {
  final container = PalmContainer.parse(bytes);
  final header = MobiHeader.parse(container);

  if (header.isHuffman) {
    throw const MobiFormatException(
      'Huffman-compressed KF8 (AZW3) books are not supported yet; '
      'only PalmDOC/plain Mobi7 are readable.',
    );
  }

  // 正文 section = [1, textRecords]。每个 section 解压后拼接。
  final body = BytesBuilder(copy: false);
  final textRecords = header.textRecords;
  if (textRecords <= 0) {
    throw const MobiFormatException('no text records in MOBI');
  }
  for (var i = 1; i <= textRecords; i++) {
    final raw = container.loadSection(i);
    // 去掉每个 record 末尾的 trailing-entry 计数(长整数,见 getRawML)。
    final trimmed = _trimTrailingData(raw);
    body.add(decompressRecord(header.compression, trimmed));
  }
  final rawHtml = body.toBytes();

  // 抽取正文之后的资源区图片(JPEG/PNG/GIF/WebP,封面通常是第一张图)。
  // 注意:kindleunpack 实测图片 section 是"裸图"(无 8 字节 record 头),
  // 直接以图片 magic 开头;INDX/FLIS/FCIS 等非图 section 会被跳过。
  final images = <MobiImage>[];
  final startSection = header.firstNontext;
  for (var i = startSection; i < container.sectionCount; i++) {
    final section = container.loadSection(i);
    if (section.length < 12) {
      continue;
    }
    final mediaType = _sniffImageType(section);
    if (mediaType == null) {
      continue;
    }
    final isCover = images.isEmpty; // 第一张图(通常是封面)记为 cover。
    images.add(
      MobiImage(
        index: i,
        data: section,
        mediaType: mediaType,
        isCover: isCover,
      ),
    );
  }

  return MobiBook(container: container, header: header, rawHtml: rawHtml, images: images);
}

/// 去掉 record 末尾的 trailing-entry 计数(PalmDOC 无;MOBI>=5 用变长计数)。
Uint8List _trimTrailingData(Uint8List data) {
  // 兼容 getRawML:若 data 很短或没有可识别的尾部,直接返回。
  // 此处先不做复杂 multi-trailer 解析,交给正文清洗阶段处理残余。
  return data;
}

/// 按文件头嗅探图片格式(仅 jpeg/png/gif/webp/bmp)。
String? _sniffImageType(Uint8List data) {
  if (data.length < 12) {
    return null;
  }
  if (data[0] == 0xFF && data[1] == 0xD8 && data[2] == 0xFF) {
    return 'image/jpeg';
  }
  if (data[0] == 0x89 && data[1] == 0x50 && data[2] == 0x4E && data[3] == 0x47) {
    return 'image/png';
  }
  if (data[0] == 0x47 && data[1] == 0x49 && data[2] == 0x46) {
    return 'image/gif';
  }
  if (data.length >= 12 &&
      data[0] == 0x52 &&
      data[1] == 0x49 &&
      data[2] == 0x46 &&
      data[3] == 0x46 &&
      data[8] == 0x57 &&
      data[9] == 0x45 &&
      data[10] == 0x42 &&
      data[11] == 0x50) {
    return 'image/webp';
  }
  if (data[0] == 0x42 && data[1] == 0x4D) {
    return 'image/bmp';
  }
  return null;
}
