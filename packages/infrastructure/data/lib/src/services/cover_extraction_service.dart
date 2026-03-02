import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

import '../services/file_service_impl.dart';
import '../services/storage_paths.dart';

class CoverExtractionService {
  CoverExtractionService({
    required StoragePaths storagePaths,
    required FileServiceImpl fileService,
  })  : _storagePaths = storagePaths,
        _fileService = fileService;

  final StoragePaths _storagePaths;
  final FileServiceImpl _fileService;

  Future<String?> extractEpubCoverToLibraryTemp({
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

    final targetPath = p.join(tempBookDir, 'cover.jpg');
    await _fileService.copyFile(source.path, targetPath);
    return 'cover.jpg';
  }

  Future<String?> _findCoverFromOpf(File opfFile, String opfPath) async {
    try {
      final xmlText = await opfFile.readAsString();
      final doc = XmlDocument.parse(xmlText);
      final opfDir = _normalizeRelative(p.posix.dirname(opfPath));

      String? coverItemId;
      for (final meta in _findByLocalName(doc, 'meta')) {
        final name = meta.getAttribute('name')?.trim().toLowerCase();
        if (name == 'cover') {
          coverItemId = meta.getAttribute('content')?.trim();
          break;
        }
      }

      if (coverItemId != null && coverItemId.isNotEmpty) {
        for (final item in _findByLocalName(doc, 'item')) {
          final id = item.getAttribute('id')?.trim();
          if (id == coverItemId) {
            final href = item.getAttribute('href')?.trim();
            if (href != null && href.isNotEmpty) {
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
        final mediaType = (item.getAttribute('media-type') ?? '')
            .trim()
            .toLowerCase();
        final likelyCover = id.contains('cover') || properties.contains('cover-image');
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
    final names = <String>[
      'cover.jpg',
      'cover.jpeg',
      'cover.png',
      'cover.webp',
      'images/cover.jpg',
      'images/cover.jpeg',
      'images/cover.png',
      'images/cover.webp',
    ];
    for (final name in names) {
      final file = File(p.joinAll(<String>[rawRoot, ..._segments(name)]));
      if (await file.exists()) {
        return _normalizeRelative(name);
      }
    }
    return null;
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
