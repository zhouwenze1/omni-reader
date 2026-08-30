import 'dart:io';

import 'package:flutter/material.dart';

import '../widgets/progress_badge.dart';

/// 书籍排行行数据(share=窗内时长占比 0~1;文案由宿主本地化)。
class StatsTopBook {
  const StatsTopBook({
    required this.title,
    required this.secondsLabel,
    required this.share,
    this.coverPath,
    this.progress,
  });

  final String title;
  final String? coverPath;
  final double? progress;
  final String secondsLabel;
  final double share;
}

/// 书籍时长排行:封面 + 书名 + 占比条 + 时长/进度。
class StatsTopBooksCard extends StatelessWidget {
  const StatsTopBooksCard({
    super.key,
    required this.title,
    required this.items,
    this.rowHeight = 64,
    this.coverWidth = 40,
    this.coverHeight = 56,
  });

  final String title;
  final List<StatsTopBook> items;
  final double rowHeight;
  final double coverWidth;
  final double coverHeight;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          SizedBox(
            height: rowHeight,
            child: Row(
              children: [
                _cover(items[i], colorScheme),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        items[i].title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: SizedBox(
                          height: 6,
                          child: Stack(
                            children: [
                              Container(
                                color: colorScheme.surfaceContainerHighest,
                              ),
                              FractionallySizedBox(
                                widthFactor: items[i].share.clamp(0.0, 1.0),
                                child: Container(
                                  color: colorScheme.primary
                                      .withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      items[i].secondsLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (items[i].progress != null) ...[
                      const SizedBox(height: 4),
                      ProgressBadge(progress: items[i].progress!),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _cover(StatsTopBook item, ColorScheme colorScheme) {
    final path = item.coverPath;
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: coverWidth,
        height: coverHeight,
        color: colorScheme.surfaceContainerHighest,
        child: path == null || path.isEmpty
            ? Icon(
                Icons.book_outlined,
                size: 20,
                color: colorScheme.onSurface.withValues(alpha: 0.4),
              )
            : Image.file(
                File(path),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.book_outlined,
                  size: 20,
                  color: colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
      ),
    );
  }
}
