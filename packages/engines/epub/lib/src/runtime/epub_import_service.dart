import 'dart:io';

import 'package:foundation_domain/domain.dart';
import 'package:path/path.dart' as p;
import 'package:reader_epub_repair/reader_epub_repair.dart';
import 'package:reader_parser_epub/reader_parser_epub.dart';

import 'book_package.dart';
import 'book_storage_service.dart';

class EpubImportService {
  EpubImportService({
    required BookStorageService storageService,
    EpubRepairer? repairer,
  })  : _storageService = storageService,
        _repairer = repairer ?? const EpubRepairer();

  final BookStorageService _storageService;
  final EpubRepairer _repairer;

  Future<BookPackage> importEpub({
    required String epubFilePath,
    required String bookUuid,
    EpubImportRepairMode repairMode = EpubImportRepairMode.repair,
    @Deprecated('Use repairMode instead.') bool? enableSmartTocReconciliation,
  }) async {
    final resolvedRepairMode = enableSmartTocReconciliation == null
        ? repairMode
        : enableSmartTocReconciliation
            ? EpubImportRepairMode.repair
            : EpubImportRepairMode.none;
    String parsePath = epubFilePath;
    Directory? repairTempDir;
    try {
      if (resolvedRepairMode == EpubImportRepairMode.repair) {
        repairTempDir = await Directory.systemTemp.createTemp(
          'reader_epub_repair_',
        );
        final repairedPath = p.join(repairTempDir.path, 'book.epub');
        await _repairer.repair(
          epubFilePath,
          outputPath: repairedPath,
        );
        parsePath = repairedPath;
      }

      final parser = EpubParser();
      final parsedPackage = await parser.parseFromFile(parsePath);
      try {
        final enrichedPackage = await EpubArtifactGenerator().generateArtifacts(
          parsedPackage,
        );
        final artifactFiles = _buildPersistedArtifactFiles(enrichedPackage);
        final package = _toBookPackage(
          bookUuid: bookUuid,
          parsedPackage: enrichedPackage,
        );
        await _storageService.prepareBookDirs(bookUuid);
        try {
          await _storageService.saveArchive(
            bookUuid,
            sourceFilePath: parsePath,
          );
          await _storageService.savePackage(package);
          await _storageService.deleteArtifactIfExists(bookUuid, 'content.json');
          await _storageService.saveArtifactFileMap(
            bookUuid,
            artifactFiles,
          );
        } catch (_) {
          await _storageService.clearBook(bookUuid);
          rethrow;
        }
        return package;
      } finally {
        await parsedPackage.close();
      }
    } finally {
      if (repairTempDir != null && await repairTempDir.exists()) {
        await repairTempDir.delete(recursive: true);
      }
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

  String? _nullableText(String? value) {
    if (value == null) {
      return null;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Map<String, Map<String, Object?>> _buildPersistedArtifactFiles(
    EpubBookPackage package,
  ) {
    final files = <String, Map<String, Object?>>{};
    final artifactEntries = package.artifacts.toFileMap().entries;
    for (final entry in artifactEntries) {
      if (entry.key == 'content.json') {
        continue;
      }

      final json = Map<String, Object?>.from(entry.value);
      if (entry.key == 'manifest.json') {
        _removeContentSearchLink(json);
      }
      files[entry.key] = json;
    }
    return files;
  }

  void _removeContentSearchLink(Map<String, Object?> manifestJson) {
    final rawLinks = manifestJson['links'];
    if (rawLinks is! List) {
      return;
    }

    final filteredLinks = rawLinks
        .whereType<Map>()
        .map((link) => link.map((key, value) => MapEntry('$key', value)))
        .where((link) {
      final rel = '${link['rel'] ?? ''}'.trim().toLowerCase();
      final href = '${link['href'] ?? ''}'.trim().toLowerCase();
      return rel != 'search' && href != 'content.json';
    }).toList(growable: false);

    if (filteredLinks.isEmpty) {
      manifestJson.remove('links');
      return;
    }
    manifestJson['links'] = filteredLinks;
  }
}
