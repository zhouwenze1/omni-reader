import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:reader_parser_core/reader_parser_core.dart';
import 'package:xml/xml.dart';

import '../services/storage_paths.dart';

class CoverExtractionService {
  CoverExtractionService({
    required StoragePaths storagePaths,
  }) : _storagePaths = storagePaths;

  final StoragePaths _storagePaths;

  Future<String?> extractEpubCoverToLibraryTemp({
    required String bookUid,
    required String opfPath,
    required String tempBookDir,
  }) async {
    final archiveCover = await _extractFromArchive(
      bookUid: bookUid,
      opfPath: opfPath,
      tempBookDir: tempBookDir,
    );
    if (archiveCover != null) {
      return archiveCover;
    }

    return _extractFromLegacyRaw(
      bookUid: bookUid,
      opfPath: opfPath,
      tempBookDir: tempBookDir,
    );
  }

  Future<String?> _extractFromArchive({
    required String bookUid,
    required String opfPath,
    required String tempBookDir,
  }) async {
    final archivePath =
        p.join(_storagePaths.booksRoot.path, bookUid, 'book.epub');
    final archiveFile = File(archivePath);
    if (!await archiveFile.exists()) {
      return null;
    }

    final source = await LazyZipResourceSource.open(archivePath);
    try {
      final normalizedOpfPath = _normalizeRelative(opfPath);
      final opfXml = await source.readText(normalizedOpfPath);
      if (opfXml == null || opfXml.trim().isEmpty) {
        return null;
      }

      String? relativeCoverPath = _findCoverFromOpfXml(opfXml, opfPath);
      relativeCoverPath ??= await _findCoverByCommonNamesInSource(source);
      if (relativeCoverPath == null || relativeCoverPath.isEmpty) {
        return null;
      }

      final bytes = await source.readBytes(relativeCoverPath);
      if (bytes == null || bytes.isEmpty) {
        return null;
      }

      return await _writeCoverBytes(
        tempBookDir: tempBookDir,
        relativeCoverPath: relativeCoverPath,
        bytes: bytes,
      );
    } finally {
      await source.close();
    }
  }

  Future<String?> _extractFromLegacyRaw({
    required String bookUid,
    required String opfPath,
    required String tempBookDir,
  }) async {
    final rawRoot = p.join(_storagePaths.booksRoot.path, bookUid, 'raw');
    final opfAbsPath = p.joinAll(<String>[rawRoot, ..._segments(opfPath)]);
    final opfFile = File(opfAbsPath);
    if (!await opfFile.exists()) {
      return null;
    }

    String? relativeCoverPath = await _findCoverFromOpf(opfFile, opfPath);
    relativeCoverPath ??= await _findCoverByCommonNames(rawRoot);
    if (relativeCoverPath == null || relativeCoverPath.isEmpty) {
      return null;
    }

    final source = File(
      p.joinAll(<String>[rawRoot, ..._segments(relativeCoverPath)]),
    );
    if (!await source.exists()) {
      return null;
    }

    final bytes = await source.readAsBytes();
    if (bytes.isEmpty) {
      return null;
    }

    return _writeCoverBytes(
      tempBookDir: tempBookDir,
      relativeCoverPath: relativeCoverPath,
      bytes: bytes,
    );
  }

  Future<String?> _findCoverFromOpf(File opfFile, String opfPath) async {
    try {
      final xmlText = await opfFile.readAsString();
      return _findCoverFromOpfXml(xmlText, opfPath);
    } catch (_) {
      return null;
    }
  }

  String? _findCoverFromOpfXml(String xmlText, String opfPath) {
    try {
      final doc = XmlDocument.parse(xmlText);
      final opfDir = _normalizeRelative(p.posix.dirname(opfPath));

      String? coverItemId;
      for (final meta in _findByLocalName(doc, 'meta')) {
        final name = meta.getAttribute('name')?.trim().toLowerCase();
        if (name == 'cover') {
          coverItemId = meta.getAttribute('content')?.trim();
          if (coverItemId != null && coverItemId.isNotEmpty) {
            break;
          }
        }
      }

      if (coverItemId != null && coverItemId.isNotEmpty) {
        for (final item in _findByLocalName(doc, 'item')) {
          final id = item.getAttribute('id')?.trim();
          if (id == coverItemId) {
            final href = item.getAttribute('href')?.trim();
            final mediaType =
                (item.getAttribute('media-type') ?? '').trim().toLowerCase();
            if (href != null &&
                href.isNotEmpty &&
                mediaType.startsWith('image/')) {
              return _resolveRelative(opfDir, href);
            }
          }
        }
      }

      for (final item in _findByLocalName(doc, 'item')) {
        final id = (item.getAttribute('id') ?? '').trim().toLowerCase();
        final properties =
            (item.getAttribute('properties') ?? '').trim().toLowerCase();
        final href = (item.getAttribute('href') ?? '').trim();
        final mediaType =
            (item.getAttribute('media-type') ?? '').trim().toLowerCase();
        final likelyCover =
            id.contains('cover') || properties.contains('cover-image');
        final imageType = mediaType.startsWith('image/');
        if (likelyCover && href.isNotEmpty && imageType) {
          return _resolveRelative(opfDir, href);
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<String?> _findCoverByCommonNames(String rawRoot) async {
    for (final name in _commonCoverNames) {
      final file = File(p.joinAll(<String>[rawRoot, ..._segments(name)]));
      if (await file.exists()) {
        return _normalizeRelative(name);
      }
    }
    return null;
  }

  Future<String?> _findCoverByCommonNamesInSource(
    BookResourceSource source,
  ) async {
    for (final name in _commonCoverNames) {
      if (await source.exists(name)) {
        return _normalizeRelative(name);
      }
    }

    final candidates = await source.listPaths();
    for (final candidate in candidates) {
      final normalized = _normalizeRelative(candidate);
      final basename = p.posix.basename(normalized).toLowerCase();
      if (_commonCoverBasenames.contains(basename)) {
        return normalized;
      }
    }
    return null;
  }

  Future<String> _writeCoverBytes({
    required String tempBookDir,
    required String relativeCoverPath,
    required Uint8List bytes,
  }) async {
    final ext = _coverFileExtension(relativeCoverPath);
    final targetName = 'cover$ext';
    final targetPath = p.join(tempBookDir, targetName);
    await Directory(p.dirname(targetPath)).create(recursive: true);
    await File(targetPath).writeAsBytes(bytes, flush: true);
    return targetName;
  }

  Iterable<XmlElement> _findByLocalName(XmlNode node, String localName) {
    return node.descendants.whereType<XmlElement>().where(
          (element) => element.name.local.toLowerCase() == localName,
        );
  }

  String _resolveRelative(String baseDir, String href) {
    final normalizedHref = href.replaceAll('\\', '/').trim();
    if (baseDir.isEmpty) {
      return _normalizeRelative(normalizedHref);
    }
    return _normalizeRelative(p.posix.join(baseDir, normalizedHref));
  }

  String _coverFileExtension(String relativeCoverPath) {
    final ext = p.extension(relativeCoverPath).trim().toLowerCase();
    if (ext == '.jpg' || ext == '.jpeg' || ext == '.png' || ext == '.webp') {
      return ext;
    }
    return '.jpg';
  }

  String _normalizeRelative(String value) {
    final normalized = p.posix.normalize(value.replaceAll('\\', '/').trim());
    if (normalized == '.' || normalized.isEmpty) {
      return '';
    }
    return normalized.replaceFirst(RegExp(r'^/+'), '');
  }

  List<String> _segments(String value) {
    return value.split('/').where((segment) => segment.isNotEmpty).toList();
  }
}

const List<String> _commonCoverNames = <String>[
  'cover.jpg',
  'cover.jpeg',
  'cover.png',
  'cover.webp',
  'images/cover.jpg',
  'images/cover.jpeg',
  'images/cover.png',
  'images/cover.webp',
];

const Set<String> _commonCoverBasenames = <String>{
  'cover.jpg',
  'cover.jpeg',
  'cover.png',
  'cover.webp',
};
