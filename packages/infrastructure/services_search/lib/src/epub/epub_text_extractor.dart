import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import 'package:reader_parser_core/reader_parser_core.dart';
import 'package:reader_parser_epub/reader_parser_epub.dart';

import '../models.dart';

/// Reads chapter texts from an EPUB using the in-house parser stack
/// (`reader_parser_epub`).
///
/// Each chapter is parsed as XML and split into block-level elements aligned
/// with the DOM the renderer paginates, so every paragraph carries a
/// chapter-local CFI element path plus per-text-node anchors. Chapters that
/// fail to parse as XML (lenient HTML, unknown entities, …) return raw HTML
/// text with no segments — the index builder then uses line-based
/// segmentation with approximate CFIs.
///
/// Chapter-level CFIs use the progress shape the renderer documents:
/// `epubcfi(/6/<2*(spineIndex+1)>!)`.
class EpubTextExtractor implements ChapterTextSource {
  const EpubTextExtractor();

  /// Common HTML entities the XML parser does not know without a DTD.
  static const Map<String, String> _entities = <String, String>{
    'nbsp': '\u00a0',
    'copy': '\u00a9',
    'reg': '\u00ae',
    'trade': '\u2122',
    'hellip': '\u2026',
    'mdash': '\u2014',
    'ndash': '\u2013',
    'lsquo': '\u2018',
    'rsquo': '\u2019',
    'ldquo': '\u201c',
    'rdquo': '\u201d',
    'laquo': '\u00ab',
    'raquo': '\u00bb',
    'times': '\u00d7',
    'divide': '\u00f7',
    'plusmn': '\u00b1',
    'bull': '\u2022',
    'dagger': '\u2020',
    'euro': '\u20ac',
    'pound': '\u00a3',
    'yen': '\u00a5',
    'cent': '\u00a2',
    'sect': '\u00a7',
    'para': '\u00b6',
    'middot': '\u00b7',
  };

  /// Elements whose children are block-level containers; a block element that
  /// contains any of these is recursed into and never emitted itself, so each
  /// text is emitted exactly once from its innermost block leaf.
  static const Set<String> _blockContainers = <String>{
    'div', 'section', 'article', 'body', 'blockquote', 'li', 'dd', 'dt',
    'figure', 'main', 'aside', 'header', 'footer', 'nav', 'table', 'tr',
    'ul', 'ol', 'dl',
  };

  @override
  Future<List<ChapterText>> readChapters(Uint8List epubBytes) async {
    final source = await _MemoryZipResourceSource.open(epubBytes);
    final parser = EpubParser();
    final package = await parser.parseFromSource(source);
    try {
      final chapters = <ChapterText>[];
      for (var index = 0; index < package.readingOrder.length; index++) {
        final item = package.readingOrder[index];
        if (!_isHtmlDocument(item)) {
          continue;
        }
        // readingOrder hrefs are relative to contentRoot; read with the
        // archive-absolute path but report the contentRoot-relative href
        // (same shape as spine manifest hrefs).
        final archivePath = package.contentRoot.isEmpty
            ? item.href
            : '${package.contentRoot}/${item.href}';
        final html = await source.readText(archivePath);
        if (html == null || html.isEmpty) {
          continue;
        }
        chapters.add(
          ChapterText(
            spineIndex: index,
            href: item.href,
            cfi: 'epubcfi(/6/${2 * (index + 1)}!)',
            text: html,
            segments: _extractSegments(html),
          ),
        );
      }
      return chapters;
    } finally {
      await package.close();
    }
  }

  /// Splits a chapter into DOM-aligned block segments. Returns null when the
  /// document cannot be parsed as XML (caller falls back to raw HTML text).
  List<ChapterSegment>? _extractSegments(String html) {
    XmlDocument document;
    try {
      document = XmlDocument.parse(_sanitizeForXmlParser(html));
    } catch (_) {
      return null;
    }

    final body = _findByLocalName(document.rootElement, 'body');
    final root = body ?? document.rootElement;

    final segments = <ChapterSegment>[];
    // body 本身对应渲染器的分页 scope(contentEl),不占 CFI 步;
    // 其子元素从 /2 开始。
    _visitBlock(root, const <int>[], segments);
    return segments.isEmpty ? null : segments;
  }

  /// Depth-first walk over element children, tracking the element index path
  /// the renderer's CFI resolver walks (element step = `(index + 1) * 2`,
  /// counted among element children only; [elementPath] is empty for the
  /// body itself and `/2…` for its children).
  void _visitBlock(
    XmlElement element,
    List<int> elementPath,
    List<ChapterSegment> out,
  ) {
    var hasBlockChildren = false;
    var elementChildIndex = 0;
    for (final child in element.childElements) {
      if (_blockContainers.contains(child.name.local.toLowerCase())) {
        hasBlockChildren = true;
        _visitBlock(
          child,
          <int>[...elementPath, (elementChildIndex + 1) * 2],
          out,
        );
      }
      elementChildIndex++;
    }

    if (hasBlockChildren) {
      return;
    }

    final builder = _SegmentTextBuilder();
    _appendNodeText(element, elementPath, builder);
    if (builder.text.trim().isEmpty || builder.anchors.isEmpty) {
      return;
    }
    out.add(
      ChapterSegment(
        text: builder.text,
        cfiPath: _pathToString(elementPath),
        anchors: builder.anchors,
      ),
    );
  }

  void _appendNodeText(
    XmlNode node,
    List<int> currentPath,
    _SegmentTextBuilder builder,
  ) {
    for (final child in node.nodes) {
      if (child is XmlText) {
        // 渲染器 getTextChildren 只统计文本节点;步骤 = textIndex * 2 + 1。
        final siblings = child.parent!.nodes.whereType<XmlText>().toList();
        final textIndex = siblings.indexOf(child);
        builder.addText(
          child.value,
          _pathToString([...currentPath, textIndex * 2 + 1]),
        );
      } else if (child is XmlElement) {
        final siblings = child.parent!.childElements.toList(growable: false);
        final elementIndex = siblings.indexOf(child);
        _appendNodeText(
          child,
          [...currentPath, (elementIndex + 1) * 2],
          builder,
        );
      }
    }
  }

  String _pathToString(List<int> steps) {
    return steps.map((step) => '/$step').join();
  }

  bool _isHtmlDocument(BookAssetItem item) {
    final mediaType = item.mediaType.trim().toLowerCase();
    if (mediaType == 'application/xhtml+xml' || mediaType == 'text/html') {
      return true;
    }
    if (mediaType.isEmpty) {
      final lower = item.href.toLowerCase();
      return lower.endsWith('.xhtml') ||
          lower.endsWith('.html') ||
          lower.endsWith('.htm');
    }
    return false;
  }

  XmlElement? _findByLocalName(XmlElement root, String localName) {
    if (root.name.local.toLowerCase() == localName) {
      return root;
    }
    for (final child in root.childElements) {
      final found = _findByLocalName(child, localName);
      if (found != null) {
        return found;
      }
    }
    return null;
  }

  String _sanitizeForXmlParser(String html) {
    var text = html.replaceFirst(
      RegExp(r'<!DOCTYPE[^]*?>', caseSensitive: false),
      '',
    );
    // 未定义的 HTML 实体替换为等价字符;数字实体由解析器原生支持。
    text = text.replaceAllMapped(
      RegExp('&([a-zA-Z][a-zA-Z0-9]*);'),
      (match) {
        final name = match.group(1)!.toLowerCase();
        return _entities[name] ?? ' ';
      },
    );
    return text;
  }
}

/// Accumulates the normalized display text of one block element while
/// recording, per text node, where it starts in the display text and how many
/// raw characters were collapsed before its first kept character.
class _SegmentTextBuilder {
  final StringBuffer _buffer = StringBuffer();
  final List<DomTextAnchor> _anchors = <DomTextAnchor>[];
  bool _lastWasSpace = true;

  List<DomTextAnchor> get anchors => _anchors;

  String get text => _buffer.toString();

  void addText(String raw, String terminalPath) {
    final start = _buffer.length;
    var kept = 0;
    var collapsedLeading = 0;
    for (var i = 0; i < raw.length; i++) {
      final ch = raw[i];
      if (_isWhitespace(ch)) {
        if (_lastWasSpace) {
          continue;
        }
        _buffer.write(' ');
        _lastWasSpace = true;
      } else {
        _buffer.write(ch);
        _lastWasSpace = false;
      }
      if (kept == 0) {
        collapsedLeading = i;
      }
      kept++;
    }
    if (kept > 0) {
      _anchors.add(
        DomTextAnchor(
          start: start,
          path: terminalPath,
          rawAdjust: collapsedLeading,
        ),
      );
    }
  }

  static bool _isWhitespace(String ch) {
    return ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r';
  }
}

/// In-memory [BookResourceSource] over decoded zip entries, mirroring the
/// path-normalization semantics of the parser's file-backed sources.
class _MemoryZipResourceSource implements BookResourceSource {
  _MemoryZipResourceSource._(Map<String, Uint8List> entries)
      : _entries = entries;

  static Future<_MemoryZipResourceSource> open(Uint8List bytes) async {
    final archive = ZipDecoder().decodeBytes(bytes, verify: false);
    final entries = <String, Uint8List>{};
    for (final file in archive.files) {
      if (!file.isFile) {
        continue;
      }
      entries[_normalize(file.name)] = file.content;
    }
    return _MemoryZipResourceSource._(entries);
  }

  final Map<String, Uint8List> _entries;

  @override
  String get sourceId => 'memory:zip';

  @override
  Future<List<String>> listPaths() async =>
      _entries.keys.toList(growable: false);

  @override
  Future<bool> exists(String relativePath) async =>
      _entries.containsKey(_normalize(relativePath));

  @override
  Future<Uint8List?> readBytes(String relativePath) async =>
      _entries[_normalize(relativePath)];

  @override
  Future<String?> readText(
    String relativePath, {
    Encoding encoding = utf8,
  }) async {
    final bytes = _entries[_normalize(relativePath)];
    if (bytes == null) {
      return null;
    }
    return encoding.decode(bytes);
  }

  @override
  String? contentTypeFor(String relativePath) {
    final lower = relativePath.toLowerCase();
    if (lower.endsWith('.xhtml') ||
        lower.endsWith('.html') ||
        lower.endsWith('.htm')) {
      return 'application/xhtml+xml';
    }
    if (lower.endsWith('.opf')) {
      return 'application/oebps-package+xml';
    }
    if (lower.endsWith('.ncx')) {
      return 'application/x-dtbncx+xml';
    }
    if (lower.endsWith('.css')) {
      return 'text/css';
    }
    if (lower.endsWith('.png')) {
      return 'image/png';
    }
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    return 'application/octet-stream';
  }

  @override
  Future<void> close() async {}

  static String _normalize(String value) {
    return value.replaceAll('\\', '/').trim();
  }
}
