import 'package:reader_parser_core/reader_parser_core.dart';
import 'package:xml/xml.dart';

import '../models/epub_book_package.dart';
import 'epub_toc_reconciler.dart';
import 'epub_parser_options.dart';

class EpubParser implements FormatParser<EpubBookPackage> {
  EpubParser({this.options = const EpubParserOptions()});

  static const _containerPath = 'META-INF/container.xml';
  static const EpubTocReconciler _tocReconciler = EpubTocReconciler();

  final EpubParserOptions options;

  @override
  BookFormat get format => BookFormat.epub;

  @override
  bool supportsFile(String filePath) {
    return BookFormat.fromFilePath(filePath) == BookFormat.epub;
  }

  @override
  Future<EpubBookPackage> parseFromFile(String filePath) async {
    final resourceSource = await LazyZipResourceSource.open(filePath);
    return parseFromSource(resourceSource, sourcePath: filePath);
  }

  /// Parses an EPUB from an already-opened resource source.
  ///
  /// On success the returned package takes ownership of [source]; close it
  /// via [ParsedBookPackage.close]. On failure the source is closed before
  /// rethrowing.
  Future<EpubBookPackage> parseFromSource(
    BookResourceSource source, {
    String sourcePath = 'memory:book',
  }) async {
    try {
      await _validateMimeType(source);

      final containerXml = await source.readText(_containerPath);
      if (containerXml == null || containerXml.trim().isEmpty) {
        throw StateError('Invalid EPUB: META-INF/container.xml is missing');
      }

      final opfPath = _readOpfPath(containerXml);
      final opfXml = await source.readText(opfPath);
      if (opfXml == null || opfXml.trim().isEmpty) {
        throw StateError('Invalid EPUB: OPF not found at $opfPath');
      }

      final contentRoot = PathUtils.dirname(opfPath);
      final packageDoc = XmlDocument.parse(opfXml);

      final metadata = _parseMetadata(packageDoc);
      final manifestById = _parseManifest(packageDoc, contentRoot);
      final spineIds = <String>[];
      final readingOrder = _parseReadingOrder(
        packageDoc,
        manifestById,
        spineIds,
      );
      final resources = manifestById.entries
          .where((entry) => !spineIds.contains(entry.key))
          .map((entry) => entry.value)
          .toList(growable: false);

      final navPath = manifestById.values
          .where((item) => item.properties.contains('nav'))
          .map((item) => item.href)
          .cast<String?>()
          .firstWhere((item) => item != null, orElse: () => null);

      final ncxPath = manifestById.values
          .where((item) => item.mediaType == 'application/x-dtbncx+xml')
          .map((item) => item.href)
          .cast<String?>()
          .firstWhere((item) => item != null, orElse: () => null);

      final rawToc = await _parseToc(
        resourceSource: source,
        contentRoot: contentRoot,
        navPath: navPath,
        ncxPath: ncxPath,
      );
      final toc = options.enableSmartTocReconciliation
          ? await _tocReconciler.reconcile(
              toc: rawToc,
              readingOrder: readingOrder,
              resourceSource: source,
              contentRoot: contentRoot,
            )
          : rawToc;

      return EpubBookPackage(
        sourcePath: sourcePath,
        metadata: metadata,
        contentRoot: contentRoot,
        readingOrder: readingOrder,
        resources: resources,
        toc: toc,
        resourceSource: source,
        opfPath: opfPath,
        containerPath: _containerPath,
        manifestById: manifestById,
        spineIds: spineIds,
        navPath: navPath,
        ncxPath: ncxPath,
      );
    } catch (_) {
      await source.close();
      rethrow;
    }
  }

  @override
  Future<BookMetadata> parseInfo(String filePath) async {
    final package = await parseFromFile(filePath);
    try {
      return package.metadata;
    } finally {
      await package.close();
    }
  }

  Future<void> _validateMimeType(BookResourceSource source) async {
    final mimeType = await source.readText('mimetype');
    if (mimeType == null || mimeType.trim() != 'application/epub+zip') {
      throw StateError('Invalid EPUB: mimetype is missing or invalid');
    }
  }

  String _readOpfPath(String containerXml) {
    final doc = XmlDocument.parse(containerXml);
    final rootFile = _findFirstByLocalName(doc, 'rootfile');
    final path = rootFile?.getAttribute('full-path')?.trim();
    if (path == null || path.isEmpty) {
      throw StateError('Invalid EPUB: rootfile full-path missing');
    }
    return PathUtils.normalizeRelative(path);
  }

  BookMetadata _parseMetadata(XmlDocument packageDoc) {
    final metadataElement = _findFirstByLocalName(packageDoc, 'metadata');
    if (metadataElement == null) {
      return const BookMetadata();
    }

    String? identifier;
    String? title;
    String? language;
    String? publisher;
    String? publicationDate;
    String? description;
    String? rights;
    final authors = <String>[];
    final subjects = <String>[];
    final extras = <String, Object?>{};
    String? coverId;

    for (final child in metadataElement.children.whereType<XmlElement>()) {
      final local = child.name.local.toLowerCase();
      final value = child.innerText.trim();
      if (value.isEmpty && local != 'meta') {
        continue;
      }
      switch (local) {
        case 'identifier':
          identifier ??= value;
          break;
        case 'title':
          title ??= value;
          break;
        case 'creator':
          authors.add(value);
          break;
        case 'language':
          language ??= value;
          break;
        case 'publisher':
          publisher ??= value;
          break;
        case 'date':
          publicationDate ??= value;
          break;
        case 'description':
          description ??= value;
          break;
        case 'subject':
          subjects.add(value);
          break;
        case 'rights':
          rights ??= value;
          break;
        case 'meta':
          final name = child.getAttribute('name')?.trim().toLowerCase();
          final property = child.getAttribute('property')?.trim().toLowerCase();
          final content = child.getAttribute('content')?.trim();
          if (name == 'cover' && content != null && content.isNotEmpty) {
            coverId = content;
          } else if (property != null && content != null) {
            extras[property] = content;
          }
          break;
        default:
          extras[local] = value;
          break;
      }
    }

    return BookMetadata(
      identifier: identifier,
      title: title,
      authors: authors,
      language: language,
      publisher: publisher,
      publicationDate: publicationDate,
      description: description,
      subjects: subjects,
      rights: rights,
      coverPath: coverId,
      extras: extras,
    );
  }

  Map<String, BookAssetItem> _parseManifest(
    XmlDocument packageDoc,
    String contentRoot,
  ) {
    final manifestElement = _findFirstByLocalName(packageDoc, 'manifest');
    if (manifestElement == null) {
      throw StateError('Invalid EPUB: manifest missing');
    }

    final manifest = <String, BookAssetItem>{};
    for (final item in _findChildrenByLocalName(manifestElement, 'item')) {
      final id = item.getAttribute('id')?.trim();
      final href = item.getAttribute('href')?.trim();
      final mediaType = item.getAttribute('media-type')?.trim();
      if (id == null || id.isEmpty || href == null || href.isEmpty) {
        continue;
      }
      if (mediaType == null || mediaType.isEmpty) {
        continue;
      }
      final properties = _splitProperties(item.getAttribute('properties'));
      manifest[id] = BookAssetItem(
        id: id,
        href: PathUtils.joinRelative(
          contentRoot,
          href,
        ).replaceFirst(RegExp('^${RegExp.escape(contentRoot)}/?'), ''),
        mediaType: mediaType,
        properties: properties,
        linear: true,
      );
    }
    if (manifest.isEmpty) {
      throw StateError('Invalid EPUB: manifest is empty');
    }
    return manifest;
  }

  List<BookAssetItem> _parseReadingOrder(
    XmlDocument packageDoc,
    Map<String, BookAssetItem> manifestById,
    List<String> spineIds,
  ) {
    final spineElement = _findFirstByLocalName(packageDoc, 'spine');
    if (spineElement == null) {
      throw StateError('Invalid EPUB: spine missing');
    }
    final readingOrder = <BookAssetItem>[];
    for (final itemRef in _findChildrenByLocalName(spineElement, 'itemref')) {
      final idRef = itemRef.getAttribute('idref')?.trim();
      if (idRef == null || idRef.isEmpty) {
        continue;
      }
      final manifestItem = manifestById[idRef];
      if (manifestItem == null) {
        continue;
      }
      spineIds.add(idRef);
      final linear =
          (itemRef.getAttribute('linear')?.trim().toLowerCase() ?? 'yes') !=
          'no';
      readingOrder.add(
        BookAssetItem(
          id: manifestItem.id,
          href: manifestItem.href,
          mediaType: manifestItem.mediaType,
          properties: manifestItem.properties,
          linear: linear,
          title: manifestItem.title,
        ),
      );
    }
    if (readingOrder.isEmpty) {
      throw StateError('Invalid EPUB: reading order is empty');
    }
    return readingOrder;
  }

  Future<List<BookTocItem>> _parseToc({
    required BookResourceSource resourceSource,
    required String contentRoot,
    required String? navPath,
    required String? ncxPath,
  }) async {
    if (navPath != null && navPath.isNotEmpty) {
      final toc = await _parseNavDocument(
        resourceSource: resourceSource,
        fullPath: PathUtils.joinRelative(contentRoot, navPath),
      );
      if (toc.isNotEmpty) {
        return toc;
      }
    }
    if (ncxPath != null && ncxPath.isNotEmpty) {
      final toc = await _parseNcxDocument(
        resourceSource: resourceSource,
        fullPath: PathUtils.joinRelative(contentRoot, ncxPath),
      );
      if (toc.isNotEmpty) {
        return toc;
      }
    }
    return const <BookTocItem>[];
  }

  Future<List<BookTocItem>> _parseNavDocument({
    required BookResourceSource resourceSource,
    required String fullPath,
  }) async {
    final navXml = await resourceSource.readText(fullPath);
    if (navXml == null || navXml.trim().isEmpty) {
      return const <BookTocItem>[];
    }
    final doc = XmlDocument.parse(navXml);
    final navElements = _findAllByLocalName(doc, 'nav');
    XmlElement? navElement;
    for (final candidate in navElements) {
      for (final attr in candidate.attributes) {
        final name = attr.name.local.toLowerCase();
        final value = attr.value.toLowerCase();
        if (name == 'type' && value.contains('toc')) {
          navElement = candidate;
          break;
        }
      }
      if (navElement != null) {
        break;
      }
    }
    navElement ??= navElements.isEmpty ? null : navElements.first;
    if (navElement == null) {
      return const <BookTocItem>[];
    }

    final baseDir = PathUtils.dirname(fullPath);
    final rootLists = _findChildrenByLocalName(navElement, 'ol');
    if (rootLists.isEmpty) {
      return const <BookTocItem>[];
    }

    final toc = <BookTocItem>[];
    var order = 0;

    void visitList(
      XmlElement listElement, {
      required int level,
      String? parentId,
    }) {
      for (final li in _findChildrenByLocalName(listElement, 'li')) {
        final link = _findFirstByLocalName(li, 'a');
        if (link == null) {
          continue;
        }
        final href = link.getAttribute('href')?.trim();
        final title = link.innerText.trim();
        if (href == null || href.isEmpty || title.isEmpty) {
          continue;
        }
        final itemId = 'toc_$order';
        toc.add(
          BookTocItem(
            id: itemId,
            title: title,
            href: PathUtils.joinRelative(baseDir, href),
            order: order,
            level: level,
            parentId: parentId,
          ),
        );
        order += 1;
        final childList = _findChildrenByLocalName(li, 'ol');
        if (childList.isNotEmpty) {
          visitList(childList.first, level: level + 1, parentId: itemId);
        }
      }
    }

    visitList(rootLists.first, level: 0);
    return toc;
  }

  Future<List<BookTocItem>> _parseNcxDocument({
    required BookResourceSource resourceSource,
    required String fullPath,
  }) async {
    final ncxXml = await resourceSource.readText(fullPath);
    if (ncxXml == null || ncxXml.trim().isEmpty) {
      return const <BookTocItem>[];
    }
    final doc = XmlDocument.parse(ncxXml);
    final navMap = _findFirstByLocalName(doc, 'navMap');
    if (navMap == null) {
      return const <BookTocItem>[];
    }
    final baseDir = PathUtils.dirname(fullPath);
    final toc = <BookTocItem>[];
    var order = 0;

    void visitNavPoint(
      XmlElement navPoint, {
      required int level,
      String? parentId,
    }) {
      final labelElement = _findFirstByLocalName(navPoint, 'text');
      final contentElement = _findFirstByLocalName(navPoint, 'content');
      final href = contentElement?.getAttribute('src')?.trim();
      final title = labelElement?.innerText.trim() ?? '';
      if (href == null || href.isEmpty || title.isEmpty) {
        return;
      }
      final rawId = navPoint.getAttribute('id')?.trim();
      final itemId = rawId != null && rawId.isNotEmpty ? rawId : 'toc_$order';
      toc.add(
        BookTocItem(
          id: itemId,
          title: title,
          href: PathUtils.joinRelative(baseDir, href),
          order: order,
          level: level,
          parentId: parentId,
        ),
      );
      order += 1;
      for (final child in _findChildrenByLocalName(navPoint, 'navPoint')) {
        visitNavPoint(child, level: level + 1, parentId: itemId);
      }
    }

    for (final navPoint in _findChildrenByLocalName(navMap, 'navPoint')) {
      visitNavPoint(navPoint, level: 0);
    }
    return toc;
  }

  List<String> _splitProperties(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const <String>[];
    }
    return raw
        .split(RegExp(r'\s+'))
        .map((token) => token.trim())
        .where((token) => token.isNotEmpty)
        .toList(growable: false);
  }

  XmlElement? _findFirstByLocalName(XmlNode node, String localName) {
    for (final element in _findAllByLocalName(node, localName)) {
      return element;
    }
    return null;
  }

  List<XmlElement> _findAllByLocalName(XmlNode node, String localName) {
    return node.descendants
        .whereType<XmlElement>()
        .where((element) {
          return element.name.local.toLowerCase() == localName.toLowerCase();
        })
        .toList(growable: false);
  }

  List<XmlElement> _findChildrenByLocalName(XmlElement node, String localName) {
    return node.children
        .whereType<XmlElement>()
        .where((element) {
          return element.name.local.toLowerCase() == localName.toLowerCase();
        })
        .toList(growable: false);
  }
}
