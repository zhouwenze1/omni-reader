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
    required this.selectionMode,
    required this.multiSelected,
    required this.onTap,
    this.onLongPress,
  });

  final LibraryIndexEntry entry;
  final String? coverPath;
  final bool selected;
  final bool selectionMode;
  final bool multiSelected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final coverHeight =
            (constraints.maxHeight * 0.58).clamp(96.0, 152.0).toDouble();
        final coverWidth = (coverHeight * 0.72).toDouble();
        final cardColor = multiSelected
            ? Theme.of(context).colorScheme.primaryContainer
            : selected
                ? Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withValues(alpha: 0.55)
                : Theme.of(context).colorScheme.surface;

        return Card(
          color: cardColor,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 5, 4, 5),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: Stack(
                      children: [
                        BookCover(
                          filePath: coverPath,
                          width: coverWidth,
                          height: coverHeight,
                        ),
                        if (selectionMode)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                multiSelected
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                size: 20,
                                color: multiSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 5),
                  SizedBox(
                    height: 34,
                    child: Align(
                      alignment: Alignment.center,
                      child: Text(
                        entry.title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _relativeLastRead(
                            context,
                            entry.lastOpenedAt ?? entry.updatedAt,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      ProgressBadge(progress: entry.cachedProgress ?? 0),
                    ],
                  ),
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
