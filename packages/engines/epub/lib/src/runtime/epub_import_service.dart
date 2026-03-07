import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:reader_parser_epub/reader_parser_epub.dart';

import 'book_package.dart';
import 'book_storage_service.dart';

class EpubImportService {
  EpubImportService({required BookStorageService storageService})
      : _storageService = storageService;

  final BookStorageService _storageService;

  Future<BookPackage> importEpub({
    required String epubFilePath,
    required String bookUuid,
    bool enableSmartTocReconciliation = true,
  }) async {
    final parser = EpubParser(
      options: EpubParserOptions(
        enableSmartTocReconciliation: enableSmartTocReconciliation,
      ),
    );
    final parsedPackage = await parser.parseFromFile(epubFilePath);

    try {
      final package = _toBookPackage(
        bookUuid: bookUuid,
        parsedPackage: parsedPackage,
      );

      await _storageService.prepareBookDirs(bookUuid);
      try {
        await _storageService.clearRaw(bookUuid);
        await _extractEpubToRaw(
          epubFilePath: epubFilePath,
          rawDirPath: _storageService.rawDirPath(bookUuid),
        );
        await _storageService.savePackage(package);
      } catch (_) {
        await _storageService.clearBook(bookUuid);
        rethrow;
      }

      return package;
    } finally {
      await parsedPackage.close();
    }
  }

  BookPackage _toBookPackage({
    required String bookUuid,
    required EpubBookPackage parsedPackage,
  }) {
    final authors = parsedPackage.metadata.authors
        .map((author) => author.trim())
        .where((author) => author.isNotEmpty)
        .toList(growable: false);

    return BookPackage(
      bookUuid: bookUuid,
      opfPath: parsedPackage.opfPath,
      contentRoot: parsedPackage.contentRoot,
      spineItems: parsedPackage.readingOrder
          .map(
            (item) => BookSpineItem(
              id: item.id,
              href: item.href,
              mediaType: item.mediaType,
              properties: item.properties,
              linear: item.linear,
            ),
          )
          .toList(growable: false),
      toc: parsedPackage.toc
          .map(
            (item) => BookTocItem(
              id: item.id,
              title: item.title,
              href: item.href,
              order: item.order,
              level: item.level,
              parentId: item.parentId,
            ),
          )
          .toList(growable: false),
      title: _nullableText(parsedPackage.metadata.title),
      authors: authors,
      description: _nullableText(parsedPackage.metadata.description),
      language: _nullableText(parsedPackage.metadata.language),
    );
  }

  Future<void> _extractEpubToRaw({
    required String epubFilePath,
    required String rawDirPath,
  }) async {
    final sourceFile = File(epubFilePath);
    if (!await sourceFile.exists()) {
      throw StateError('EPUB file not found: $epubFilePath');
    }

    final bytes = await sourceFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes, verify: true);

    final normalizedRawRoot = p.normalize(rawDirPath);
    for (final entry in archive.files) {
      final relative = _sanitizeArchivePath(entry.name);
      if (relative == null || relative.isEmpty) {
        continue;
      }

      final outputPath = p.normalize(
        p.joinAll(
          <String>[
            normalizedRawRoot,
            ...relative.split('/').where((segment) => segment.isNotEmpty),
          ],
        ),
      );

      if (!_isInside(normalizedRawRoot, outputPath)) {
        continue;
      }

      if (entry.isFile) {
        await Directory(p.dirname(outputPath)).create(recursive: true);
        final file = File(outputPath);
        final content = entry.content;
        if (content is List<int>) {
          await file.writeAsBytes(content, flush: true);
        } else if (content is String) {
          await file.writeAsString(content, encoding: utf8, flush: true);
        } else {
          throw StateError('Unsupported archive entry type: ${entry.name}');
        }
      } else {
        await Directory(outputPath).create(recursive: true);
      }
    }
  }

  bool _isInside(String root, String candidatePath) {
    if (p.equals(root, candidatePath)) {
      return true;
    }
    return p.isWithin(root, candidatePath);
  }

  String? _sanitizeArchivePath(String path) {
    final unified = path.replaceAll('\\', '/').trim();
    if (unified.isEmpty) {
      return null;
    }
    final normalized = p.posix.normalize(unified);
    if (normalized.isEmpty ||
        normalized == '.' ||
        normalized.startsWith('../')) {
      return null;
    }
    return normalized.replaceFirst(RegExp(r'^/+'), '');
  }

  String? _nullableText(String? value) {
    if (value == null) {
      return null;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
