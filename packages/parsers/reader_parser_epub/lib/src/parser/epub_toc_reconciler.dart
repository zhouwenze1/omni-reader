import 'dart:math';

import 'package:reader_parser_core/reader_parser_core.dart';
import 'package:xml/xml.dart';

class EpubTocReconciler {
  const EpubTocReconciler();

  static final RegExp _sectionMarkerPattern = RegExp(
    r'(?:^|[\s_\-])'
    r'(?:part|book|section|volume|vol|arc|unit|act|episode|appendix|appendices|'
    r'prologue|epilogue|interlude|extras?)'
    r'(?:$|[\s_\-\d])|'
    r'(?:第?[0-9一二三四五六七八九十百千万零两壹贰叁肆伍陆柒捌玖拾佰仟]+'
    r'(?:卷|部|篇|册|集|幕|章回))|'
    r'(?:卷|部|篇|册|集|幕|序章|终章|終章|附录|附錄|后记|後記|番外|外传|外傳)',
    caseSensitive: false,
  );

  Future<List<BookTocItem>> reconcile({
    required List<BookTocItem> toc,
    required List<BookAssetItem> readingOrder,
    required BookResourceSource resourceSource,
    required String contentRoot,
  }) async {
    final spineEntries = <_SpineEntry>[];
    for (var index = 0; index < readingOrder.length; index += 1) {
      final item = readingOrder[index];
      if (!item.isHtmlLike || !item.linear) {
        continue;
      }
      spineEntries.add(
        _SpineEntry(
          spineIndex: index,
          asset: item,
          matchKey: _matchKey(item.href, contentRoot),
          tocHref: _toTocHref(item.href, contentRoot),
        ),
      );
    }

    if (spineEntries.isEmpty) {
      return _reindexToc(toc);
    }

    if (toc.isEmpty) {
      return _buildFallbackToc(
        spineEntries: spineEntries,
        resourceSource: resourceSource,
        contentRoot: contentRoot,
      );
    }

    final spineByKey = <String, _SpineEntry>{
      for (final entry in spineEntries) entry.matchKey: entry,
    };
    final childrenByParent = <String?, List<_TocNode>>{};
    final nodeById = <String, _TocNode>{};
    final existingNodes = <_TocNode>[];

    for (var index = 0; index < toc.length; index += 1) {
      final item = toc[index];
      final matchKey = _matchKey(item.href, contentRoot);
      final spineEntry = spineByKey[matchKey];
      final node = _TocNode(
        id: item.id,
        title: _normalizeTitle(item.title),
        href: item.href,
        parentId: item.parentId,
        originalLevel: item.level,
        originalOrder: index,
        baseMatchKey: matchKey.isEmpty ? null : matchKey,
        spineIndex: spineEntry?.spineIndex,
        isSynthetic: false,
      );
      existingNodes.add(node);
      nodeById[node.id] = node;
      childrenByParent.putIfAbsent(node.parentId, () => <_TocNode>[]).add(node);
    }

    for (final node in existingNodes) {
      final childCount = childrenByParent[node.id]?.length ?? 0;
      node.hasExistingChildren = childCount > 0;
      node.isSectionLike = _isSectionLike(node);
    }

    final orderedExistingNodes = List<_TocNode>.from(existingNodes)
      ..sort(_compareNodeOrder);
    for (var index = 0; index < orderedExistingNodes.length; index += 1) {
      final node = orderedExistingNodes[index];
      node.endSpineExclusive = _findBoundarySpineIndex(
        orderedExistingNodes: orderedExistingNodes,
        nodeIndex: index,
      );
    }

    final handledKeys = <String>{
      for (final node in existingNodes)
        if (node.baseMatchKey != null && node.baseMatchKey!.isNotEmpty)
          node.baseMatchKey!,
    };
    final allNodes = List<_TocNode>.from(existingNodes);
    var syntheticOrderSeed = existingNodes.length;

    for (final spineEntry in spineEntries) {
      if (handledKeys.contains(spineEntry.matchKey)) {
        continue;
      }

      final parent = _findLogicalParent(
        spineEntry: spineEntry,
        existingNodes: orderedExistingNodes,
        allNodes: allNodes,
      );
      final title = await _resolveTitle(
        spineEntry: spineEntry,
        resourceSource: resourceSource,
        contentRoot: contentRoot,
      );

      final node = _TocNode(
        id: 'reconciled_${syntheticOrderSeed}_${_slugId(spineEntry.matchKey)}',
        title: title,
        href: spineEntry.tocHref,
        parentId: parent?.id,
        originalLevel: parent == null ? 0 : parent.originalLevel + 1,
        originalOrder: syntheticOrderSeed,
        baseMatchKey: spineEntry.matchKey,
        spineIndex: spineEntry.spineIndex,
        isSynthetic: true,
      );
      syntheticOrderSeed += 1;
      nodeById[node.id] = node;
      allNodes.add(node);
      childrenByParent.putIfAbsent(node.parentId, () => <_TocNode>[]).add(node);
      handledKeys.add(spineEntry.matchKey);
    }

    for (final siblings in childrenByParent.values) {
      siblings.sort(_compareNodeOrder);
    }

    final flattened = <BookTocItem>[];
    var nextOrder = 0;

    void visit(String? parentId, int level) {
      final siblings = childrenByParent[parentId];
      if (siblings == null || siblings.isEmpty) {
        return;
      }
      for (final node in siblings) {
        flattened.add(
          BookTocItem(
            id: node.id,
            title: node.title,
            href: node.href,
            order: nextOrder,
            level: level,
            parentId: parentId,
          ),
        );
        nextOrder += 1;
        visit(node.id, level + 1);
      }
    }

    visit(null, 0);

    if (flattened.isEmpty) {
      return _buildFallbackToc(
        spineEntries: spineEntries,
        resourceSource: resourceSource,
        contentRoot: contentRoot,
      );
    }
    return flattened;
  }

  Future<List<BookTocItem>> _buildFallbackToc({
    required List<_SpineEntry> spineEntries,
    required BookResourceSource resourceSource,
    required String contentRoot,
  }) async {
    final toc = <BookTocItem>[];
    for (var index = 0; index < spineEntries.length; index += 1) {
      final spineEntry = spineEntries[index];
      toc.add(
        BookTocItem(
          id: 'fallback_$index',
          title: await _resolveTitle(
            spineEntry: spineEntry,
            resourceSource: resourceSource,
            contentRoot: contentRoot,
          ),
          href: spineEntry.tocHref,
          order: index,
          level: 0,
          parentId: null,
        ),
      );
    }
    return toc;
  }

  _TocNode? _findLogicalParent({
    required _SpineEntry spineEntry,
    required List<_TocNode> existingNodes,
    required List<_TocNode> allNodes,
  }) {
    final candidates = existingNodes.where((node) {
      final start = node.spineIndex;
      final end = node.endSpineExclusive;
      if (!node.isSectionLike || start == null) {
        return false;
      }
      return start < spineEntry.spineIndex && spineEntry.spineIndex < end;
    }).toList(growable: false)
      ..sort((left, right) {
        final levelCompare = _nodeLevelScore(right).compareTo(
          _nodeLevelScore(left),
        );
        if (levelCompare != 0) {
          return levelCompare;
        }
        return (right.spineIndex ?? -1).compareTo(left.spineIndex ?? -1);
      });
    if (candidates.isNotEmpty) {
      return candidates.first;
    }

    _TocNode? previousNode;
    for (final node in allNodes) {
      final spineIndex = node.spineIndex;
      if (spineIndex == null || spineIndex >= spineEntry.spineIndex) {
        continue;
      }
      if (previousNode == null || _compareNodeOrder(previousNode, node) < 0) {
        previousNode = node;
      }
    }
    if (previousNode == null) {
      return null;
    }
    if (previousNode.parentId == null) {
      return null;
    }
    return allNodes.cast<_TocNode?>().firstWhere(
          (node) => node?.id == previousNode?.parentId,
          orElse: () => null,
        );
  }

  int _findBoundarySpineIndex({
    required List<_TocNode> orderedExistingNodes,
    required int nodeIndex,
  }) {
    final node = orderedExistingNodes[nodeIndex];
    for (var index = nodeIndex + 1; index < orderedExistingNodes.length; index += 1) {
      final candidate = orderedExistingNodes[index];
      final candidateSpineIndex = candidate.spineIndex;
      if (candidateSpineIndex == null) {
        continue;
      }
      if (_nodeLevelScore(candidate) <= _nodeLevelScore(node)) {
        return candidateSpineIndex;
      }
    }
    return 1 << 30;
  }

  bool _isSectionLike(_TocNode node) {
    if (node.hasExistingChildren) {
      return true;
    }
    final title = node.title.trim();
    final href = PathUtils.basename(node.href);
    return _sectionMarkerPattern.hasMatch(title) ||
        _sectionMarkerPattern.hasMatch(href);
  }

  int _compareNodeOrder(_TocNode left, _TocNode right) {
    final leftSpine = left.spineIndex ?? (1 << 30);
    final rightSpine = right.spineIndex ?? (1 << 30);
    final spineCompare = leftSpine.compareTo(rightSpine);
    if (spineCompare != 0) {
      return spineCompare;
    }
    return left.originalOrder.compareTo(right.originalOrder);
  }

  int _nodeLevelScore(_TocNode node) {
    return node.originalLevel;
  }

  Future<String> _resolveTitle({
    required _SpineEntry spineEntry,
    required BookResourceSource resourceSource,
    required String contentRoot,
  }) async {
    final itemTitle = spineEntry.asset.title?.trim();
    if (itemTitle != null && itemTitle.isNotEmpty) {
      return itemTitle;
    }

    final fullPath = PathUtils.joinRelative(contentRoot, spineEntry.asset.href);
    final xhtml = await resourceSource.readText(fullPath);
    if (xhtml != null && xhtml.trim().isNotEmpty) {
      final extracted = _extractTitleFromXhtml(xhtml);
      if (extracted != null && extracted.isNotEmpty) {
        return extracted;
      }
    }
    return _fallbackFileTitle(spineEntry.asset.href);
  }

  String? _extractTitleFromXhtml(String xhtml) {
    final trimmed = xhtml.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    try {
      final document = XmlDocument.parse(trimmed);
      final candidates = <String?>[
        _firstTextByTag(document, 'title'),
        _firstTextByTag(document, 'h1'),
        _firstTextByTag(document, 'h2'),
        _firstTextByTag(document, 'h3'),
        _firstTextByTag(document, 'p'),
      ];
      for (final candidate in candidates) {
        final normalized = _normalizeTitle(candidate);
        if (normalized.isNotEmpty) {
          return normalized;
        }
      }
      final bodyElements = document.findAllElements('body');
      if (bodyElements.isNotEmpty) {
        final body = bodyElements.first;
        final normalized = _normalizeTitle(body.innerText);
        if (normalized.isNotEmpty) {
          return normalized;
        }
      }
    } catch (_) {
      final fallback = trimmed
          .replaceAll(RegExp(r'<[^>]+>'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      final normalized = _normalizeTitle(fallback);
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }

    return null;
  }

  String? _firstTextByTag(XmlDocument document, String localName) {
    for (final element in document.descendants.whereType<XmlElement>()) {
      if (element.name.local.toLowerCase() != localName.toLowerCase()) {
        continue;
      }
      final normalized = _normalizeTitle(element.innerText);
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }
    return null;
  }

  String _normalizeTitle(String? input) {
    if (input == null) {
      return '';
    }
    final normalized = input
        .replaceAll('\u00A0', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (normalized.isEmpty) {
      return '';
    }

    final words = normalized.split(RegExp(r'\s+'));
    if (words.length <= 12 && normalized.length <= 96) {
      return normalized;
    }
    if (words.length > 12) {
      return '${words.take(12).join(' ')}...';
    }
    return '${normalized.substring(0, min(96, normalized.length)).trim()}...';
  }

  String _fallbackFileTitle(String href) {
    final basename = PathUtils.basename(href);
    final dotIndex = basename.lastIndexOf('.');
    if (dotIndex <= 0) {
      return basename;
    }
    return basename.substring(0, dotIndex);
  }

  String _matchKey(String href, String contentRoot) {
    var value = href.trim();
    final queryIndex = value.indexOf('?');
    if (queryIndex >= 0) {
      value = value.substring(0, queryIndex);
    }
    final hashIndex = value.indexOf('#');
    if (hashIndex >= 0) {
      value = value.substring(0, hashIndex);
    }
    value = Uri.decodeFull(value);
    value = PathUtils.normalizeRelative(value);
    final root = PathUtils.normalizeRelative(contentRoot);
    if (root.isEmpty || value.isEmpty) {
      return value;
    }
    if (value == root) {
      return '';
    }
    if (value.startsWith('$root/')) {
      return value.substring(root.length + 1);
    }
    return value;
  }

  String _toTocHref(String href, String contentRoot) {
    return PathUtils.joinRelative(contentRoot, href);
  }

  String _slugId(String value) {
    final sanitized = value
        .replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return sanitized.isEmpty ? 'item' : sanitized.toLowerCase();
  }

  List<BookTocItem> _reindexToc(List<BookTocItem> toc) {
    if (toc.isEmpty) {
      return const <BookTocItem>[];
    }
    return toc
        .asMap()
        .entries
        .map(
          (entry) => BookTocItem(
            id: entry.value.id,
            title: entry.value.title,
            href: entry.value.href,
            order: entry.key,
            level: entry.value.level,
            parentId: entry.value.parentId,
          ),
        )
        .toList(growable: false);
  }
}

class _SpineEntry {
  const _SpineEntry({
    required this.spineIndex,
    required this.asset,
    required this.matchKey,
    required this.tocHref,
  });

  final int spineIndex;
  final BookAssetItem asset;
  final String matchKey;
  final String tocHref;
}

class _TocNode {
  _TocNode({
    required this.id,
    required this.title,
    required this.href,
    required this.parentId,
    required this.originalLevel,
    required this.originalOrder,
    required this.baseMatchKey,
    required this.spineIndex,
    required this.isSynthetic,
  });

  final String id;
  final String title;
  final String href;
  final String? parentId;
  final int originalLevel;
  final int originalOrder;
  final String? baseMatchKey;
  final int? spineIndex;
  final bool isSynthetic;
  bool hasExistingChildren = false;
  bool isSectionLike = false;
  int endSpineExclusive = 1 << 30;
}
