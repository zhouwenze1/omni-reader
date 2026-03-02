import 'package:flutter/material.dart';
import 'package:foundation_domain/domain.dart';

import 'book_cover.dart';
import 'progress_badge.dart';

class BookListItem extends StatelessWidget {
  const BookListItem({
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
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5)
              : null,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            BookCover(filePath: coverPath, width: 54, height: 76, radius: 8),
            const SizedBox(width: 10),
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
