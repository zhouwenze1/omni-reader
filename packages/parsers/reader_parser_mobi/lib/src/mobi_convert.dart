import 'package:reader_epub_repair/reader_epub_repair.dart';
import 'package:reader_parser_core/reader_parser_core.dart';

import 'mobi_cleaner.dart';
import 'mobi_reader.dart';

/// 一部 MOBI 反解 + 清洗 + 分章后的"可落盘产物"。
///
/// 上层(导入)拿到 [chapters]/[toc]/[cover] 后,按 contentRoot 布局写成
/// `Text/*.xhtml` + `Images/*`,并生成 EPUB 引擎要的 meta.json。
class MobiConvertedBook {
  MobiConvertedBook({
    required this.title,
    required this.authors,
    required this.language,
    required this.chapters,
    required this.toc,
    required this.images,
    this.description,
  });

  final String? title;
  final List<String> authors;
  final String? language;
  final String? description;

  /// 章节(href 相对 contentRoot,如 `Text/chapter0001.xhtml`)。
  final List<MobiChapter> chapters;

  /// TOC(锚点指向章节 href + 片内 id;无 id 则指向 href)。
  final List<BookTocItem> toc;

  /// 落盘的图片(相对 contentRoot 的 href,如 `Images/img0001.jpeg`)。
  final List<MobiConvertedImage> images;
}

class MobiChapter {
  MobiChapter({required this.href, required this.xhtml});

  final String href;
  final String xhtml;
}

class MobiConvertedImage {
  MobiConvertedImage({
    required this.href,
    required this.data,
    required this.mediaType,
    required this.isCover,
  });

  final String href;
  final List<int> data;
  final String mediaType;
  final bool isCover;
}

/// 把 [MobiBook] 清洗分章成可落盘产物。
MobiConvertedBook convertMobiBook(MobiBook book) {
  final cleaner = const MobiCleaner();
  // recindex 是 1-based 资源槽号(以 firstResource 为槽 0),槽可能被非图
  // 资源占用——交给 reader 按 KindleUnpack 的 rscnames 语义解析。
  String? imagePathOf(int rec) {
    final img = book.imageForRecindex(rec);
    if (img == null) {
      return null;
    }
    return '../Images/${_imageFileName(img.index, img.mediaType)}';
  }

  final pieces = cleaner.cleanAndSplit(
    book.rawHtml,
    book.header.codepage,
    imagePathOf: imagePathOf,
  );

  // 组装章节 XHTML(用 repair 的序列化保证良构)。
  final chapters = <MobiChapter>[];
  for (var i = 0; i < pieces.length; i++) {
    final href = 'Text/chapter${(i + 1).toString().padLeft(4, '0')}.xhtml';
    final xhtml = _wrapChapter(pieces[i]);
    chapters.add(MobiChapter(href: href, xhtml: xhtml));
  }

  // 图片落盘清单(含封面/缩略图,按出现序)。
  final convertedImages = <MobiConvertedImage>[];
  for (final img in book.images) {
    convertedImages.add(
      MobiConvertedImage(
        href: 'Images/${_imageFileName(img.index, img.mediaType)}',
        data: img.data,
        mediaType: img.mediaType,
        isCover: img.isCover,
      ),
    );
  }

  // TOC:每章标题 = 页内标题文本;图片页取 <img alt>(漫画页码);都没有才占位。
  final toc = <BookTocItem>[];
  for (var i = 0; i < chapters.length; i++) {
    final title = _pieceTitle(pieces[i]) ?? 'Chapter ${i + 1}';
    toc.add(
      BookTocItem(
        id: 'toc-${i + 1}',
        title: title,
        href: chapters[i].href,
        order: i + 1,
      ),
    );
  }

  return MobiConvertedBook(
    title: book.header.title,
    authors: book.header.authors,
    language: book.header.language,
    description: book.header.description,
    chapters: chapters,
    toc: toc,
    images: convertedImages,
  );
}

/// 把一段清洗后的 body 内容包成完整 XHTML 文档(良构,带 head/body)。
String _wrapChapter(String bodyHtml) {
  return repairMalformedXhtml(
    '<html xmlns="http://www.w3.org/1999/xhtml"><head>'
    '<meta charset="utf-8" /><title>Chapter</title></head>'
    '<body>$bodyHtml</body></html>',
  );
}

/// 取片段标题文本,用作 TOC 标题。
///
/// 顺序:页内 h1-h6 → 图片页的 <img alt>(漫画页码,如 "第 N 頁")→ 首个
/// 短 <p> 文本 → null(调用方用 "Chapter N" 兜底)。
String? _pieceTitle(String piece) {
  final m = RegExp(
    r'<h[1-6][^>]*>(.*?)</h[1-6]>',
    caseSensitive: false,
    dotAll: true,
  ).firstMatch(piece);
  if (m != null) {
    return _decodeEntities(_stripTags(m.group(1)!).trim());
  }
  // 整页是图(漫画):取 img 的 alt(通常是页码/页标题)。
  final imgAlt = RegExp(
    r'<img[^>]*\balt="([^"]*)"[^>]*>',
    caseSensitive: false,
  ).firstMatch(piece);
  if (imgAlt != null) {
    final alt = _decodeEntities(imgAlt.group(1)!.trim());
    if (alt.isNotEmpty && alt.length < 80) {
      return alt;
    }
  }
  // mobipocket 常无 h 标签,标题是居中大字 <p>:取首个非空 <p> 文本。
  final p = RegExp(
    r'<p[^>]*>(.*?)</p>',
    caseSensitive: false,
    dotAll: true,
  ).firstMatch(piece);
  if (p != null) {
    final text = _stripTags(p.group(1)!).trim();
    if (text.isNotEmpty && text.length < 80) {
      return text;
    }
  }
  return null;
}

String _stripTags(String html) => html.replaceAll(RegExp(r'<[^>]+>'), ' ');

/// 属性值里的常见实体(alt 可能含 &amp; 等)。
String _decodeEntities(String raw) => raw
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&nbsp;', '\u00A0');

String _imageFileName(int sectionIndex, String mediaType) {
  final ext = switch (mediaType) {
    'image/jpeg' => 'jpg',
    'image/png' => 'png',
    'image/gif' => 'gif',
    'image/webp' => 'webp',
    'image/bmp' => 'bmp',
    _ => 'img',
  };
  return 'img${sectionIndex.toString().padLeft(4, '0')}.$ext';
}
