import 'dart:convert';
import 'dart:math';

import 'package:reader_parser_core/reader_parser_core.dart';
import 'package:xml/xml.dart';

import '../models/epub_book_package.dart';
import '../models/epub_node_locator.dart';

class EpubArtifactGenerator implements DerivativeGenerator<EpubBookPackage> {
  EpubArtifactGenerator({
    this.positionTextStep = 1024,
    this.contentBlockMaxLength = 2000,
    Set<String>? locatableTags,
  }) : locatableTags =
           locatableTags ??
           const <String>{
             'p',
             'h1',
             'h2',
             'h3',
             'h4',
             'h5',
             'h6',
             'li',
             'blockquote',
             'img',
           };

  final int positionTextStep;
  final int contentBlockMaxLength;
  final Set<String> locatableTags;

  @override
  Future<EpubBookPackage> generateArtifacts(EpubBookPackage package) async {
    final locatorsByHref = await _buildLocators(package);
    final manifest = _buildManifest(package);
    final positions = await _buildPositions(package, locatorsByHref);
    final content = await _buildContent(package, positions, locatorsByHref);

    return package.copyWith(
      locatorsByHref: locatorsByHref,
      artifacts: BookArtifactBundle(
        manifest: manifest,
        positions: positions,
        content: content,
      ),
    );
  }

  BookManifestDocument _buildManifest(EpubBookPackage package) {
    final readingOrder = package.readingOrder
        .where((item) => item.linear)
        .map(
          (item) => <String, Object?>{
            'href': item.href,
            'type': item.mediaType,
            if (item.properties.isNotEmpty)
              'properties': item.properties.join(' '),
            'title': item.title,
          },
        )
        .toList(growable: false);

    final resources = package.resources
        .map(
          (item) => <String, Object?>{
            'href': item.href,
            'type': item.mediaType,
            if (item.properties.isNotEmpty)
              'properties': item.properties.join(' '),
          },
        )
        .toList(growable: false);

    return BookManifestDocument(
      metadata: <String, Object?>{
        'identifier': package.metadata.identifier,
        'title': package.metadata.title,
        'author': package.metadata.authors,
        'language': package.metadata.language,
        'publisher': package.metadata.publisher,
        'description': package.metadata.description,
        'subject': package.metadata.subjects,
        'rights': package.metadata.rights,
      },
      readingOrder: readingOrder,
      resources: resources,
      toc: _buildNestedToc(package.toc),
      links: const <Map<String, Object?>>[
        <String, Object?>{
          'rel': 'self',
          'href': 'manifest.json',
          'type': 'application/webpub+json',
        },
        <String, Object?>{
          'rel': 'positions',
          'href': 'positions.json',
          'type': 'application/vnd.readium.position-list+json',
        },
        <String, Object?>{
          'rel': 'search',
          'href': 'content.json',
          'type': 'application/vnd.readium.content+json',
        },
      ],
    );
  }

  Future<BookPositionDocument> _buildPositions(
    EpubBookPackage package,
    Map<String, List<EpubNodeLocator>> locatorsByHref,
  ) async {
    final htmlItems = package.readingOrder
        .where((item) => item.linear && item.isHtmlLike)
        .toList(growable: false);

    final countsByHref = <String, int>{};
    for (final item in htmlItems) {
      final fullPath = PathUtils.joinRelative(package.contentRoot, item.href);
      final xhtml = await package.resourceSource.readText(fullPath) ?? '';
      final plainText = _extractPlainText(xhtml);
      countsByHref[item.href] = max(
        1,
        (plainText.length / positionTextStep).ceil(),
      );
    }

    final total = countsByHref.values.fold<int>(0, (sum, value) => sum + value);
    if (total == 0) {
      return const BookPositionDocument(
        total: 0,
        positions: <BookPositionEntry>[],
      );
    }

    final entries = <BookPositionEntry>[];
    var globalPosition = 0;
    for (final item in htmlItems) {
      final count = countsByHref[item.href] ?? 1;
      final locators = locatorsByHref[item.href] ?? const <EpubNodeLocator>[];
      for (var index = 0; index < count; index += 1) {
        globalPosition += 1;
        final progression = count == 1 ? 0.0 : index / (count - 1);
        final totalProgression = total == 1
            ? 0.0
            : (globalPosition - 1) / (total - 1);
        final locator = _nearestLocator(locators, progression);
        entries.add(
          BookPositionEntry(
            href: item.href,
            mediaType: item.mediaType,
            locations: <String, Object?>{
              'position': globalPosition,
              'progression': _round6(progression),
              'totalProgression': _round6(totalProgression),
              if (locator != null)
                'cfi': _buildLegacyLocator(item.href, locator),
              if (locator != null) 'uid': locator.uid,
              if (locator != null) 'xpath': locator.xpath,
            },
          ),
        );
      }
    }

    return BookPositionDocument(total: entries.length, positions: entries);
  }

  Future<BookContentDocument> _buildContent(
    EpubBookPackage package,
    BookPositionDocument positions,
    Map<String, List<EpubNodeLocator>> locatorsByHref,
  ) async {
    final hrefPositions = <String, List<Map<String, Object?>>>{};
    for (final entry in positions.positions) {
      hrefPositions
          .putIfAbsent(entry.href, () => <Map<String, Object?>>[])
          .add(entry.locations);
    }

    final blocks = <BookContentBlock>[];
    for (final item in package.readingOrder.where(
      (entry) => entry.linear && entry.isHtmlLike,
    )) {
      final fullPath = PathUtils.joinRelative(package.contentRoot, item.href);
      final xhtml = await package.resourceSource.readText(fullPath);
      if (xhtml == null || xhtml.trim().isEmpty) {
        continue;
      }
      final doc = XmlDocument.parse(xhtml);
      final body = _firstBody(doc);
      if (body == null) {
        continue;
      }
      final locators = locatorsByHref[item.href] ?? const <EpubNodeLocator>[];
      final totalTextLength = _estimateTotalLength(locators);
      for (final locator in locators) {
        if (!_isTextualTag(locator.tag)) {
          continue;
        }
        final element = _findByXPath(body, locator.xpath);
        if (element == null) {
          continue;
        }
        final text = _normalizeWhitespace(element.innerText);
        if (text.isEmpty) {
          continue;
        }
        final progression = totalTextLength == 0
            ? 0.0
            : min(1.0, locator.textStart / totalTextLength);
        final mappedLocation = _mapNearestLocation(
          href: item.href,
          progression: progression,
          hrefPositions: hrefPositions,
        );
        for (final chunk in _chunkText(text)) {
          blocks.add(
            BookContentBlock(
              href: item.href,
              role: _roleFor(locator.tag),
              text: chunk,
              locations: mappedLocation,
              locator: <String, Object?>{
                'uid': locator.uid,
                'xpath': locator.xpath,
                'cfi': _buildLegacyLocator(item.href, locator),
              },
            ),
          );
        }
      }
    }

    return BookContentDocument(total: blocks.length, blocks: blocks);
  }

  Future<Map<String, List<EpubNodeLocator>>> _buildLocators(
    EpubBookPackage package,
  ) async {
    final results = <String, List<EpubNodeLocator>>{};
    for (final item in package.readingOrder.where(
      (entry) => entry.linear && entry.isHtmlLike,
    )) {
      final fullPath = PathUtils.joinRelative(package.contentRoot, item.href);
      final xhtml = await package.resourceSource.readText(fullPath);
      if (xhtml == null || xhtml.trim().isEmpty) {
        continue;
      }
      final doc = XmlDocument.parse(xhtml);
      final body = _firstBody(doc);
      if (body == null) {
        continue;
      }

      final locators = <EpubNodeLocator>[];
      var runningTextOffset = 0;
      for (final element in body.descendants.whereType<XmlElement>()) {
        final tag = element.name.local.toLowerCase();
        if (!locatableTags.contains(tag)) {
          continue;
        }
        final normalizedText = _normalizeWhitespace(element.innerText);
        final textLength = tag == 'img' ? 0 : normalizedText.length;
        final xpath = _buildBodyXPath(element);
        final locator = EpubNodeLocator(
          uid: _buildUid(item.href, xpath),
          xpath: xpath,
          tag: tag,
          textStart: runningTextOffset,
          textLength: textLength,
          preview: normalizedText.substring(0, min(80, normalizedText.length)),
        );
        locators.add(locator);
        runningTextOffset += textLength;
      }
      results[item.href] = locators;
    }
    return results;
  }

  List<Map<String, Object?>> _buildNestedToc(List<BookTocItem> flatToc) {
    if (flatToc.isEmpty) {
      return const <Map<String, Object?>>[];
    }
    final byParent = <String?, List<BookTocItem>>{};
    for (final item in flatToc) {
      byParent.putIfAbsent(item.parentId, () => <BookTocItem>[]).add(item);
    }

    Map<String, Object?> buildNode(BookTocItem item) {
      final children = (byParent[item.id] ?? const <BookTocItem>[])
          .map(buildNode)
          .toList(growable: false);
      return <String, Object?>{
        'title': item.title,
        'href': item.href,
        if (children.isNotEmpty) 'children': children,
      };
    }

    return (byParent[null] ?? const <BookTocItem>[])
        .map(buildNode)
        .toList(growable: false);
  }

  EpubNodeLocator? _nearestLocator(
    List<EpubNodeLocator> locators,
    double progression,
  ) {
    if (locators.isEmpty) {
      return null;
    }
    final totalLength = _estimateTotalLength(locators);
    final targetOffset = (progression * totalLength).round();
    EpubNodeLocator? best;
    var bestDiff = 1 << 30;
    for (final locator in locators) {
      final diff = (locator.textStart - targetOffset).abs();
      if (diff < bestDiff) {
        best = locator;
        bestDiff = diff;
      }
    }
    return best;
  }

  int _estimateTotalLength(List<EpubNodeLocator> locators) {
    if (locators.isEmpty) {
      return 0;
    }
    final last = locators.last;
    return last.textStart + last.textLength;
  }

  List<String> _chunkText(String text) {
    if (text.length <= contentBlockMaxLength) {
      return <String>[text];
    }
    final chunks = <String>[];
    var start = 0;
    while (start < text.length) {
      final end = min(text.length, start + contentBlockMaxLength);
      chunks.add(text.substring(start, end));
      start = end;
    }
    return chunks;
  }

  Map<String, Object?>? _mapNearestLocation({
    required String href,
    required double progression,
    required Map<String, List<Map<String, Object?>>> hrefPositions,
  }) {
    final positions = hrefPositions[href];
    if (positions == null || positions.isEmpty) {
      return null;
    }
    Map<String, Object?>? best;
    var bestDiff = 999.0;
    for (final location in positions) {
      final rawProgression = location['progression'];
      final current = rawProgression is num ? rawProgression.toDouble() : null;
      if (current == null) {
        continue;
      }
      final diff = (current - progression).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        best = location;
      }
    }
    return best == null ? null : Map<String, Object?>.from(best);
  }

  bool _isTextualTag(String tag) {
    return tag.startsWith('h') ||
        tag == 'p' ||
        tag == 'li' ||
        tag == 'blockquote';
  }

  String _roleFor(String tag) {
    if (tag.startsWith('h')) {
      return 'heading';
    }
    if (tag == 'li') {
      return 'list_item';
    }
    if (tag == 'blockquote') {
      return 'blockquote';
    }
    return 'paragraph';
  }

  String _extractPlainText(String xhtml) {
    if (xhtml.trim().isEmpty) {
      return '';
    }
    try {
      final doc = XmlDocument.parse(xhtml);
      final body = _firstBody(doc) ?? doc.rootElement;
      return _normalizeWhitespace(body.innerText);
    } catch (_) {
      return _normalizeWhitespace(xhtml.replaceAll(RegExp(r'<[^>]+>'), ' '));
    }
  }

  XmlElement? _firstBody(XmlDocument doc) {
    final bodies = doc.findAllElements('body');
    return bodies.isEmpty ? null : bodies.first;
  }

  String _normalizeWhitespace(String input) {
    return input
        .replaceAll('\u00A0', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  double _round6(double value) {
    return (value * 1000000).round() / 1000000.0;
  }

  String _buildLegacyLocator(String href, EpubNodeLocator locator) {
    return 'cfi(href=$href;xpath=${locator.xpath};uid=${locator.uid})';
  }

  String _buildUid(String href, String xpath) {
    final input = utf8.encode('$href|$xpath');
    const offsetBasis = 0x811C9DC5;
    const prime = 0x01000193;
    var hash = offsetBasis;
    for (final unit in input) {
      hash ^= unit & 0xff;
      hash = (hash * prime) & 0xffffffff;
    }
    final encoded = hash.toRadixString(36).padLeft(8, '0');
    return 'u_${encoded.substring(max(0, encoded.length - 8))}';
  }

  String _buildBodyXPath(XmlElement element) {
    final segments = <String>[];
    XmlNode? current = element;
    while (current != null) {
      if (current is XmlElement) {
        final tag = current.name.local.toLowerCase();
        var index = 1;
        final parent = current.parentElement;
        if (parent != null) {
          final siblings = parent.children
              .whereType<XmlElement>()
              .where((candidate) => candidate.name.local.toLowerCase() == tag)
              .toList(growable: false);
          for (var cursor = 0; cursor < siblings.length; cursor += 1) {
            if (identical(siblings[cursor], current)) {
              index = cursor + 1;
              break;
            }
          }
        }
        segments.add('$tag[$index]');
        if (tag == 'body') {
          break;
        }
      }
      current = current.parent;
    }
    return '/${segments.reversed.join('/')}';
  }

  XmlElement? _findByXPath(XmlElement body, String xpath) {
    final parts = xpath.split('/').where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty || !parts.first.startsWith('body')) {
      return null;
    }
    XmlElement current = body;
    for (var index = 1; index < parts.length; index += 1) {
      final match = RegExp(
        r'^([a-zA-Z0-9:_-]+)\[(\d+)\]$',
      ).firstMatch(parts[index]);
      if (match == null) {
        return null;
      }
      final tag = match.group(1)!.toLowerCase();
      final position = int.parse(match.group(2)!);
      final candidates = current.children
          .whereType<XmlElement>()
          .where((element) => element.name.local.toLowerCase() == tag)
          .toList(growable: false);
      if (position <= 0 || position > candidates.length) {
        return null;
      }
      current = candidates[position - 1];
    }
    return current;
  }
}
