import 'dart:typed_data';

import 'mobi_container.dart';
import 'mobi_decompress.dart';
import 'mobi_huffcdic.dart';

/// 一部 MOBI 反解出的"书":正文 HTML 流 + 元数据 + 封面(若有)。
class MobiBook {
  MobiBook({
    required this.container,
    required this.header,
    required this.rawHtml,
    this.images = const <MobiImage>[],
    List<MobiImage?>? slotImages,
  }) : _slotImages = slotImages ?? <MobiImage?>[];

  final PalmContainer container;
  final MobiHeader header;

  /// 解压后的 Mobipocket HTML(未清洗,含 <mbp:pagebreak/> 等专有标签)。
  final Uint8List rawHtml;

  /// 资源区图片(含封面,按 section 出现序)。
  final List<MobiImage> images;

  /// 资源槽表:下标 = recindex - 1,值 = 该槽的图(槽可能被 FONT/索引占用)。
  final List<MobiImage?> _slotImages;

  /// 按 KindleUnpack 的 rscnames 语义把 recindex 映射为图片。
  /// recindex 是 1-based 资源槽号,槽 0 = firstResource 起的第 1 个 section。
  MobiImage? imageForRecindex(int rec) {
    if (rec <= 0 || rec > _slotImages.length) {
      return null;
    }
    return _slotImages[rec - 1];
  }
}

class MobiImage {
  MobiImage({
    required this.index,
    required this.data,
    required this.mediaType,
    required this.isCover,
  });

  /// 所在 section 号,用作稳定命名。
  final int index;
  final Uint8List data;
  final String mediaType;

  /// 是否为封面(EXTH CoverOffset 指向;缺失时回退第一张图)。
  bool isCover;
}

/// 读取 PalmDB + MOBI 头,解压正文 section 拼成 raw HTML。
///
/// 支持 Mobi7(PalmDOC/无压缩)与 KF8/Huffman(压缩 0x4448)。
/// 返回的书保留原始字节,由调用方负责 container 生命周期。
MobiBook readMobi(Uint8List bytes) {
  final container = PalmContainer.parse(bytes);
  final header = MobiHeader.parse(container);

  // 正文 section = [1, textRecords]。每个 section 解压后拼接。
  final body = BytesBuilder(copy: false);
  final textRecords = header.textRecords;
  if (textRecords <= 0) {
    throw const MobiFormatException('no text records in MOBI');
  }

  if (header.isHuffman) {
    // KF8:先按 huffOffset 定位 HUFF/CDIC section 建解码器,再逐条解压。
    final huff = MobiHuffCdic.fromContainer(container, header);
    for (var i = 1; i <= textRecords; i++) {
      final raw = container.loadSection(i);
      body.add(huff.decompress(_trimTrailingData(raw, header)));
    }
  } else {
    for (var i = 1; i <= textRecords; i++) {
      final raw = container.loadSection(i);
      body.add(
        decompressRecord(header.compression, _trimTrailingData(raw, header)),
      );
    }
  }
  final rawHtml = body.toBytes();

  // 资源区图片收集 + recindex 槽表。
  //
  // recindex 是 **1-based 资源槽号**,以 firstResource(0x6C)为第 1 个槽;
  // 槽内可能是 FONT/FLIS/FCIS 等非图(占位,无图)。KindleUnpack 遍历
  // firstResource 起每个 section 生成 rscnames,HTML 的 recindex=N 取
  // rscnames[N-1]——本实现按同一语义建立槽表,避免图与索引节交错时错位。
  final imageScan = _collectImages(container, header);

  return MobiBook(
    container: container,
    header: header,
    rawHtml: rawHtml,
    images: imageScan.images,
    slotImages: imageScan.slots,
  );
}

/// 资源收集结果:[slots] 与 [images] 共享同一 source,按 section 序。
class _ImageScan {
  _ImageScan(this.images, this.slots);

  final List<MobiImage> images;
  final List<MobiImage?> slots;
}

/// 扫 firstResource..(首个 BOUNDARY 或文件尾),返回槽表与图列表。
_ImageScan _collectImages(PalmContainer container, MobiHeader header) {
  final start = header.firstResource ?? header.firstNontext;
  // 组合 mobi 以 "BOUNDARY" section 分隔 mobi7 与 KF8 两半:只取前半,
  // 避免把 KF8 半(CRES/高清直存图等)混入正文章节用图。
  var end = container.sectionCount;
  for (var i = start; i < container.sectionCount; i++) {
    if (_isBoundary(container.loadSection(i))) {
      end = i;
      break;
    }
  }

  final images = <MobiImage>[];
  final slots = <MobiImage?>[];
  int? coverSection;
  final coverOffset = header.exthUint32(201);
  if (coverOffset != null && start + coverOffset < container.sectionCount) {
    coverSection = start + coverOffset;
  }

  for (var i = start; i < end; i++) {
    final section = container.loadSection(i);
    final mediaType = section.length >= 12 ? _sniffImageType(section) : null;
    MobiImage? image;
    if (mediaType != null) {
      image = MobiImage(
        index: i,
        data: section,
        mediaType: mediaType,
        isCover: i == coverSection,
      );
      images.add(image);
    }
    slots.add(image);
  }
  // 无 EXTH 封面偏移或指向非图时:回退第一张图(老书常见,如 alice)。
  if (images.isNotEmpty && !images.any((im) => im.isCover)) {
    images.first.isCover = true;
  }
  return _ImageScan(images, slots);
}

bool _isBoundary(Uint8List section) {
  if (section.length < 8) {
    return false;
  }
  return section[0] == 0x42 && // B
      section[1] == 0x4F && // O
      section[2] == 0x55 && // U
      section[3] == 0x4E && // N
      section[4] == 0x44 && // D
      section[5] == 0x41 && // A
      section[6] == 0x52 && // R
      section[7] == 0x59; // Y
}

/// 去掉 record 末尾的 trailing-entry 计数与 multibyte pad。
///
/// 见 kindleunpack `getRawML`:MOBI 头 0xF2 的 extra-data flags 决定有几段
/// 变长计数(每段反向大端 7bit),bit0 为 multibyte 时再剥 1 个指示字节。
Uint8List _trimTrailingData(Uint8List data, MobiHeader header) {
  if (data.isEmpty) {
    return data;
  }
  var trimmed = data;
  var flags = header.extraDataFlags;
  if (flags > 1) {
    // 去掉每段变长计数(flags>>1 的位数,含 bit0 的多字节位)。
    var trailers = 0;
    var f = flags >> 1;
    while (f > 0) {
      if (f & 1 != 0) {
        trailers++;
      }
      f >>= 1;
    }
    for (var i = 0; i < trailers && trimmed.isNotEmpty; i++) {
      final num = _trailingSize(trimmed);
      if (num <= 0 || num >= trimmed.length) {
        break;
      }
      trimmed = Uint8List.sublistView(trimmed, 0, trimmed.length - num);
    }
  }
  if (flags & 1 != 0 && trimmed.isNotEmpty) {
    // multibyte overlap:末尾字节的低 2 位 + 1 是要剥的字符数。
    final num = (trimmed[trimmed.length - 1] & 3) + 1;
    if (num < trimmed.length) {
      trimmed = Uint8List.sublistView(trimmed, 0, trimmed.length - num);
    }
  }
  return trimmed;
}

/// 变长整数(Palm 风格,反向 7bit 组)。
int _trailingSize(Uint8List data) {
  if (data.length < 4) {
    return 0;
  }
  var num = 0;
  for (var i = data.length - 4; i < data.length; i++) {
    final v = data[i];
    if (v & 0x80 != 0) {
      num = 0;
    }
    num = (num << 7) | (v & 0x7F);
  }
  return num;
}

/// 按文件头嗅探图片格式(仅 jpeg/png/gif/webp/bmp)。
String? _sniffImageType(Uint8List data) {
  if (data.length < 12) {
    return null;
  }
  if (data[0] == 0xFF && data[1] == 0xD8 && data[2] == 0xFF) {
    return 'image/jpeg';
  }
  if (data[0] == 0x89 &&
      data[1] == 0x50 &&
      data[2] == 0x4E &&
      data[3] == 0x47) {
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
