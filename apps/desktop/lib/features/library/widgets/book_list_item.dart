import 'package:flutter/material.dart';
import 'package:foundation_domain/domain.dart';

import 'book_cover.dart';
import 'package:shared_ui/shared_ui.dart';

class BookListItem extends StatelessWidget {
  const BookListItem({
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
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: multiSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : selected
                  ? Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withValues(alpha: 0.5)
                  : null,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          children: [
            if (selectionMode) ...[
              Icon(
                multiSelected
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                size: 20,
                color: multiSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
            ],
            BookCover(filePath: coverPath, width: 72, height: 102, radius: 8),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.authors.join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.format.toUpperCase(),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
            ProgressBadge(progress: entry.cachedProgress ?? 0),
          ],
        ),
      ),
    );
  }
}
