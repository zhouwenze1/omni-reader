import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

import 'book_package.dart';
import 'book_storage_service.dart';

class EpubImportService {
  EpubImportService({required BookStorageService storageService})
      : _storageService = storageService;

  final BookStorageService _storageService;

  Future<BookPackage> importEpub({
    required String epubFilePath,
    required String bookUuid,
  }) async {
    await _storageService.prepareBookDirs(bookUuid);
    await _storageService.clearRaw(bookUuid);

    final rawDirPath = _storageService.rawDirPath(bookUuid);
    await _extractEpubToRaw(epubFilePath: epubFilePath, rawDirPath: rawDirPath);

    final containerPath = p.join(rawDirPath, 'META-INF', 'container.xml');
    final containerFile = File(containerPath);
    if (!await containerFile.exists()) {
      throw StateError('Invalid EPUB: META-INF/container.xml not found');
    }

    final opfRelativePath = await _readOpfRelativePath(containerFile);
    final normalizedOpfPath = _normalizeRelative(opfRelativePath);
    final opfAbsolutePath = p.joinAll(
      <String>[
        rawDirPath,
        ...normalizedOpfPath.split('/').where((segment) => segment.isNotEmpty),
      ],
    );

    final opfFile = File(opfAbsolutePath);
    if (!await opfFile.exists()) {
      throw StateError('Invalid EPUB: OPF not found at $normalizedOpfPath');
    }

    final parsed = await _parseOpf(
      opfFile: opfFile,
      opfRelativePath: normalizedOpfPath,
      rawDirPath: rawDirPath,
    );

    final package = BookPackage(
      bookUuid: bookUuid,
      opfPath: normalizedOpfPath,
      contentRoot: parsed.contentRoot,
      spineItems: parsed.spineItems,
      toc: parsed.toc,
    );

    await _storageService.savePackage(package);
    return package;
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

  Future<String> _readOpfRelativePath(File containerFile) async {
    final xmlText = await containerFile.readAsString();
    final document = XmlDocument.parse(xmlText);
    final rootfiles = _findElementsByLocalName(document, 'rootfile');
    if (rootfiles.isEmpty) {
      throw StateError('Invalid EPUB: rootfile not found in container.xml');
    }

    final fullPath = rootfiles.first.getAttribute('full-path')?.trim();
    if (fullPath == null || fullPath.isEmpty) {
      throw StateError('Invalid EPUB: rootfile full-path is missing');
    }
    return fullPath;
  }

  Future<_ParsedOpf> _parseOpf({
    required File opfFile,
    required String opfRelativePath,
    required String rawDirPath,
  }) async {
    final xmlText = await opfFile.readAsString();
    final document = XmlDocument.parse(xmlText);

    final contentRoot = (() {
      final dir = p.posix.dirname(opfRelativePath);
      if (dir == '.' || dir.isEmpty) {
        return '';
      }
      return _normalizeRelative(dir);
    })();

    final manifestItems = <String, _ManifestItem>{};
    final manifestEntries = _findElementsByLocalName(document, 'item');
    for (final item in manifestEntries) {
      final id = item.getAttribute('id')?.trim() ?? '';
      final href = item.getAttribute('href')?.trim() ?? '';
      if (id.isEmpty || href.isEmpty) {
        continue;
      }
      final propertiesRaw = item.getAttribute('properties')?.trim() ?? '';
      final properties = propertiesRaw
          .split(RegExp(r'\s+'))
          .where((token) => token.isNotEmpty)
          .toList();

      manifestItems[id] = _ManifestItem(
        id: id,
        href: href,
        mediaType: item.getAttribute('media-type')?.trim(),
        properties: properties,
      );
    }

    final spineContainer = _firstElementByLocalName(document, 'spine');
    final spineItems = <BookSpineItem>[];
    if (spineContainer != null) {
      final itemRefs = _findElementsByLocalName(spineContainer, 'itemref');
      var order = 0;
      for (final itemRef in itemRefs) {
        final idRef = itemRef.getAttribute('idref')?.trim() ?? '';
        final manifest = manifestItems[idRef];
        if (manifest == null) {
          continue;
        }
        final linearRaw = itemRef.getAttribute('linear')?.trim().toLowerCase();
        final linear = linearRaw != 'no';
        final resolvedHref = _resolveHref(contentRoot, manifest.href);

        spineItems.add(
          BookSpineItem(
            id: manifest.id.isEmpty ? 'spine_$order' : manifest.id,
            href: resolvedHref,
            mediaType: manifest.mediaType,
            properties: manifest.properties,
            linear: linear,
          ),
        );
        order += 1;
      }
    }

    _ManifestItem? navManifest;
    for (final item in manifestItems.values) {
      if (item.properties.contains('nav')) {
        navManifest = item;
        break;
      }
    }

    final toc = <BookTocItem>[];
    if (navManifest != null) {
      final navHref = _resolveHref(contentRoot, navManifest.href);
      final navAbsolutePath = p.join(
        rawDirPath,
        p.joinAll(
          navHref.split('/').where((segment) => segment.isNotEmpty).toList(),
        ),
      );
      final navFile = File(navAbsolutePath);
      if (await navFile.exists()) {
        toc.addAll(await _parseToc(navFile: navFile, navHref: navHref));
      }
    }

    return _ParsedOpf(
      contentRoot: contentRoot,
      spineItems: spineItems,
      toc: toc,
    );
  }

  Future<List<BookTocItem>> _parseToc({
    required File navFile,
    required String navHref,
  }) async {
    final xmlText = await navFile.readAsString();
    final document = XmlDocument.parse(xmlText);
    final navElements = _findElementsByLocalName(document, 'nav');
    XmlElement? tocNav;
    for (final nav in navElements) {
      if (_isTocNav(nav)) {
        tocNav = nav;
        break;
      }
    }

    if (tocNav == null) {
      return const <BookTocItem>[];
    }

    final navBaseDir = (() {
      final dir = p.posix.dirname(navHref);
      if (dir == '.' || dir.isEmpty) {
        return '';
      }
      return _normalizeRelative(dir);
    })();

    final links = _findElementsByLocalName(tocNav, 'a').toList();
    final toc = <BookTocItem>[];
    for (var index = 0; index < links.length; index += 1) {
      final link = links[index];
      final hrefRaw = link.getAttribute('href')?.trim() ?? '';
      if (hrefRaw.isEmpty) {
        continue;
      }
      final title = _collectElementText(link).trim();
      if (title.isEmpty) {
        continue;
      }

      final href = _resolveHref(navBaseDir, hrefRaw);
      toc.add(
        BookTocItem(
          id: 'toc_$index',
          title: title,
          href: href,
          order: index,
          level: _computeListDepth(link),
        ),
      );
    }
    return toc;
  }

  bool _isTocNav(XmlElement nav) {
    for (final attribute in nav.attributes) {
      final name = attribute.name.local.toLowerCase();
      final value = attribute.value.toLowerCase();
      if (name == 'type' && value.contains('toc')) {
        return true;
      }
    }
    return false;
  }

  String _collectElementText(XmlElement element) {
    final buffer = StringBuffer();
    for (final node in element.descendants) {
      if (node is XmlText) {
        final text = node.value.replaceAll(RegExp(r'\s+'), ' ').trim();
        if (text.isEmpty) {
          continue;
        }
        if (buffer.isNotEmpty) {
          buffer.write(' ');
        }
        buffer.write(text);
      }
    }
    return buffer.toString();
  }

  int _computeListDepth(XmlElement element) {
    var depth = 0;
    XmlNode? node = element.parent;
    while (node != null) {
      if (node is XmlElement && node.name.local.toLowerCase() == 'ol') {
        depth += 1;
      }
      node = node.parent;
    }
    if (depth == 0) {
      return 0;
    }
    return depth - 1;
  }

  Iterable<XmlElement> _findElementsByLocalName(
      XmlNode node, String localName) {
    return node.descendants.whereType<XmlElement>().where(
          (element) => element.name.local.toLowerCase() == localName,
        );
  }

  XmlElement? _firstElementByLocalName(XmlNode node, String localName) {
    for (final element in _findElementsByLocalName(node, localName)) {
      return element;
    }
    return null;
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

  String _normalizeRelative(String value) {
    final normalized = p.posix.normalize(value.replaceAll('\\', '/').trim());
    if (normalized == '.' || normalized.isEmpty) {
      return '';
    }
    return normalized.replaceFirst(RegExp(r'^/+'), '');
  }

  String _resolveHref(String baseDir, String href) {
    final cleanHref = href.trim();
    if (cleanHref.isEmpty) {
      return baseDir;
    }
    if (cleanHref.startsWith('http://') || cleanHref.startsWith('https://')) {
      return cleanHref;
    }

    final parsed = Uri.tryParse(cleanHref);
    if (parsed == null) {
      final merged = baseDir.isEmpty
          ? cleanHref
          : p.posix.join(baseDir, cleanHref.replaceAll('\\', '/'));
      return _normalizeRelative(merged);
    }
    final mergedPath =
        baseDir.isEmpty ? parsed.path : p.posix.join(baseDir, parsed.path);
    final normalizedPath = _normalizeRelative(mergedPath);
    final rebuilt = Uri(
      path: normalizedPath,
      query: parsed.hasQuery ? parsed.query : null,
      fragment: parsed.hasFragment ? parsed.fragment : null,
    );
    return rebuilt.toString();
  }
}

class _ManifestItem {
  const _ManifestItem({
    required this.id,
    required this.href,
    this.mediaType,
    this.properties = const <String>[],
  });

  final String id;
  final String href;
  final String? mediaType;
  final List<String> properties;
}

class _ParsedOpf {
  const _ParsedOpf({
    required this.contentRoot,
    required this.spineItems,
    required this.toc,
  });

  final String contentRoot;
  final List<BookSpineItem> spineItems;
  final List<BookTocItem> toc;
}
