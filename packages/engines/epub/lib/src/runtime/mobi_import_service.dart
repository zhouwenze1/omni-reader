import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:reader_parser_mobi/reader_parser_mobi.dart';

import 'book_package.dart';
import 'book_storage_service.dart';

/// MOBI/AZW3 导入:反解 → 清洗分章 → 落成 EPUB 引擎能读的 raw 目录 + meta.json。
///
/// 不产 book.epub;运行时 LocalReaderHttpServer 的 raw 目录回退直接服务章节。
/// book.format 记为 'webpub'(epub 引擎已认),故书架/阅读路由零引擎改动。
class MobiImportService {
  MobiImportService({required BookStorageService storageService})
      : _storageService = storageService;

  final BookStorageService _storageService;

  static const contentRoot = 'OEBPS';

  /// 反解 [mobiFilePath] 并把产物落盘到 books/[bookUuid]/。
  /// 返回可供上层(封面/Book 记录)使用的信息。
  Future<MobiImportResult> importMobi({
    required String mobiFilePath,
    required String bookUuid,
  }) async {
    final bytes = File(mobiFilePath).readAsBytesSync();
    final book = readMobi(bytes);
    final converted = convertMobiBook(book);

    await _storageService.prepareBookDirs(bookUuid);
    try {
      // raw/<contentRoot>/Text|Images
      final rawRoot = Directory(_storageService.rawDirPath(bookUuid));
      if (!await rawRoot.exists()) {
        await rawRoot.create(recursive: true);
      }
      final contentDir = Directory(p.join(rawRoot.path, contentRoot));
      if (!await contentDir.exists()) {
        await contentDir.create(recursive: true);
      }

      // 写章节
      for (final chapter in converted.chapters) {
        final target = File(p.join(contentDir.path, chapter.href));
        await target.parent.create(recursive: true);
        await target.writeAsString(chapter.xhtml, flush: true);
      }
      // 写图片
      for (final image in converted.images) {
        final target = File(p.join(contentDir.path, image.href));
        await target.parent.create(recursive: true);
        await target.writeAsBytes(image.data, flush: true);
      }

      // meta.json
      final package = BookPackage(
        bookUuid: bookUuid,
        opfPath: '',
        contentRoot: contentRoot,
        spineItems: converted.chapters
            .map(
              (c) => BookSpineItem(
                id: c.href,
                href: c.href,
                mediaType: 'application/xhtml+xml',
              ),
            )
            .toList(growable: false),
        toc: converted.toc
            .map(
              (t) => BookTocItem(
                id: t.id,
                title: t.title,
                href: t.href,
                order: t.order,
                level: t.level,
                parentId: t.parentId,
              ),
            )
            .toList(growable: false),
        title: converted.title,
        authors: converted.authors,
        description: converted.description,
        language: converted.language,
      );
      await _storageService.savePackage(package);

      return MobiImportResult(
        title: converted.title,
        authors: converted.authors,
        language: converted.language,
        firstSpineHref: package.firstSpineHref,
        coverImage: _findCover(converted.images),
      );
    } catch (_) {
      await _storageService.clearBook(bookUuid);
      rethrow;
    }
  }

  MobiCoverImage? _findCover(List<MobiConvertedImage> images) {
    for (final image in images) {
      if (image.isCover) {
        return MobiCoverImage(data: image.data, mediaType: image.mediaType);
      }
    }
    return null;
  }
}

class MobiImportResult {
  MobiImportResult({
    this.title,
    this.authors = const <String>[],
    this.language,
    this.firstSpineHref,
    this.coverImage,
  });

  final String? title;
  final List<String> authors;
  final String? language;
  final String? firstSpineHref;
  final MobiCoverImage? coverImage;
}

class MobiCoverImage {
  MobiCoverImage({required this.data, required this.mediaType});

  final List<int> data;
  final String mediaType;
}
