import 'package:flutter/material.dart';
import 'package:foundation_domain/domain.dart';

import 'book_cover.dart';
import 'progress_badge.dart';

class BookGridItem extends StatelessWidget {
  const BookGridItem({
    super.key,
    required this.entry,
    required this.coverPath,
    required this.selected,
    required this.onTap,
  });

  final LibraryIndexEntry entry;
  final String? coverPath;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final coverHeight =
            (constraints.maxHeight * 0.46).clamp(82.0, 112.0).toDouble();
        final coverWidth = (coverHeight * 0.72).toDouble();

        return InkWell(
          onTap: onTap,
          child: Card(
            color: selected
                ? Theme.of(context).colorScheme.primaryContainer
                : Theme.of(context).colorScheme.surface,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: BookCover(
                      filePath: coverPath,
                      width: coverWidth,
                      height: coverHeight,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 36,
                    child: Text(
                      entry.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _relativeLastRead(
                      context,
                      entry.lastOpenedAt ?? entry.updatedAt,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 4),
                  ProgressBadge(progress: entry.cachedProgress ?? 0),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _relativeLastRead(BuildContext context, DateTime dateTime) {
    final isZh = Localizations.localeOf(context).languageCode.startsWith('zh');
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final startOfTarget = DateTime(dateTime.year, dateTime.month, dateTime.day);
    final days = startOfToday.difference(startOfTarget).inDays;

    if (days <= 0) {
      return isZh ? '今天' : 'Today';
    }
    if (days == 1) {
      return isZh ? '昨天' : 'Yesterday';
    }
    if (days < 7) {
      return isZh ? '$days 天前' : '$days days ago';
    }
    if (days < 14) {
      return isZh ? '一周前' : 'A week ago';
    }
    if (days < 30) {
      final weeks = (days / 7).floor();
      return isZh ? '$weeks 周前' : '$weeks weeks ago';
    }
    if (days < 365) {
      final months = (days / 30).floor();
      return isZh ? '$months 个月前' : '$months months ago';
    }
    final years = (days / 365).floor();
    return isZh ? '$years 年前' : '$years years ago';
  }
}
