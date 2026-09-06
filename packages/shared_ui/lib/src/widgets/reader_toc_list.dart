import 'dart:async';

import 'package:flutter/material.dart';
import 'package:foundation_domain/domain.dart';

class ReaderTocList extends StatefulWidget {
  const ReaderTocList({
    super.key,
    required this.items,
    required this.currentHref,
    required this.onSelect,
    this.listPadding = EdgeInsets.zero,
    this.rowExtent = 52,
    this.rightPadding = 16,
    this.dense = true,
    this.maxTitleLines = 1,
  });

  final List<TocItem> items;
  final String? currentHref;
  final ValueChanged<TocItem> onSelect;
  final EdgeInsets listPadding;
  final double rowExtent;
  final double rightPadding;
  final bool dense;
  final int maxTitleLines;

  @override
  State<ReaderTocList> createState() => _ReaderTocListState();
}

class _ReaderTocListState extends State<ReaderTocList> {
  static const _autoScrollDuration = Duration(milliseconds: 180);
  static const _autoScrollMargin = 12.0;

  final _scrollController = ScrollController();
  String? _lastAutoScrollKey;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _currentIndex();
    _scheduleAutoScroll(currentIndex);

    return ListView.builder(
      controller: _scrollController,
      padding: widget.listPadding,
      itemExtent: widget.rowExtent,
      itemCount: widget.items.length,
      itemBuilder: (context, index) {
        final item = widget.items[index];
        final enabled = item.href != null;
        final selected = index == currentIndex;
        final colors = Theme.of(context).colorScheme;
        final titleColor = selected
            ? colors.primary
            : enabled
                ? colors.onSurface
                : colors.onSurface.withValues(alpha: 0.54);

        return ListTile(
          key: ValueKey(item.id),
          dense: widget.dense,
          selected: selected,
          selectedTileColor: colors.primary.withValues(alpha: 0.16),
          selectedColor: colors.primary,
          contentPadding: EdgeInsets.only(
            left: 16 + (item.level * 16),
            right: widget.rightPadding,
          ),
          title: Text(
            item.title,
            maxLines: widget.maxTitleLines,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: titleColor,
              fontWeight: selected ? FontWeight.w600 : null,
            ),
          ),
          trailing: enabled
              ? Icon(
                  Icons.chevron_right,
                  color: selected
                      ? colors.primary
                      : colors.onSurface.withValues(alpha: 0.38),
                  size: 18,
                )
              : null,
          onTap: enabled ? () => widget.onSelect(item) : null,
        );
      },
    );
  }

  /// 选中项：先找精确命中（href 含锚点，如 current='c1.xhtml#s2' 应命中带 #s2 的
  /// 小节条目而非章节根）；无精确命中时回退到同章节（章节根或剥掉锚点同路径）。
  int _currentIndex() {
    var chapterMatch = -1;
    for (var index = 0; index < widget.items.length; index += 1) {
      if (_exactHref(widget.items[index].href, widget.currentHref)) {
        return index;
      }
      if (chapterMatch < 0 &&
          _chapterHrefEqual(widget.items[index].href, widget.currentHref)) {
        chapterMatch = index;
      }
    }
    return chapterMatch;
  }

  bool _exactHref(String? left, String? right) {
    final a = _normalizeHrefKey(left, keepFragment: true);
    final b = _normalizeHrefKey(right, keepFragment: true);
    return a.isNotEmpty && a == b;
  }

  bool _chapterHrefEqual(String? left, String? right) {
    final a = _normalizeHrefKey(left);
    final b = _normalizeHrefKey(right);
    if (a.isEmpty || b.isEmpty) {
      return false;
    }
    return a == b || a.endsWith('/$b') || b.endsWith('/$a');
  }

  void _scheduleAutoScroll(int index) {
    if (index < 0) {
      return;
    }

    final item = widget.items[index];
    final key = '${item.id}:${_normalizeHrefKey(widget.currentHref)}';
    if (_lastAutoScrollKey == key) {
      return;
    }
    _lastAutoScrollKey = key;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !_scrollController.hasClients ||
          index >= widget.items.length) {
        return;
      }

      final position = _scrollController.position;
      final itemTop = widget.listPadding.top + (index * widget.rowExtent);
      final itemBottom = itemTop + widget.rowExtent;
      final viewportTop = position.pixels;
      final viewportBottom = viewportTop + position.viewportDimension;
      if (itemTop >= viewportTop + _autoScrollMargin &&
          itemBottom <= viewportBottom - _autoScrollMargin) {
        return;
      }

      final target =
          (itemTop - ((position.viewportDimension - widget.rowExtent) / 2))
              .clamp(0.0, position.maxScrollExtent)
              .toDouble();
      if ((target - position.pixels).abs() < 1) {
        return;
      }
      unawaited(
        _scrollController.animateTo(
          target,
          duration: _autoScrollDuration,
          curve: Curves.easeOutCubic,
        ),
      );
    });
  }

  /// 归一化 href 为可比较键。默认剥掉 `#片段`；[keepFragment] 为 true 时保留
  /// 片段，用于精确锚点匹配。http(s)/book 这类绝对 URL 只取 path。
  String _normalizeHrefKey(String? raw, {bool keepFragment = false}) {
    final value = raw?.trim().replaceAll('\\', '/');
    if (value == null || value.isEmpty) {
      return '';
    }
    final parsed = Uri.tryParse(value);
    final isUrl = parsed != null &&
        (parsed.scheme == 'http' ||
            parsed.scheme == 'https' ||
            parsed.scheme == 'book');
    if (keepFragment && !isUrl) {
      return value.split('?').first;
    }
    final path = isUrl ? parsed.path : value.split('#').first.split('?').first;
    return path
        .replaceFirst(RegExp(r'^/+'), '')
        .replaceFirst(RegExp(r'/+$'), '');
  }
}
