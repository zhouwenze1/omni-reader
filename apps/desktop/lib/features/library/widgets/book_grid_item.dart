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
            (constraints.maxHeight * 0.5).clamp(92.0, 132.0).toDouble();
        final coverWidth = (coverHeight * 0.72).toDouble();

        return InkWell(
          onTap: onTap,
          child: Card(
            color: selected
                ? Theme.of(context).colorScheme.primaryContainer
                : Theme.of(context).colorScheme.surface,
            child: Padding(
              padding: const EdgeInsets.all(8),
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
                  const SizedBox(height: 8),
                  Text(
                    entry.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.authors.join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  ProgressBadge(progress: entry.cachedProgress ?? 0),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
