import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:foundation_domain/domain.dart';

import 'book_cover.dart';
import 'package:shared_ui/shared_ui.dart';

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
        final coverWidth = math.min(
          174.0,
          math.max(0.0, constraints.maxWidth - 16),
        );
        final coverHeight = coverWidth / 0.72;
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
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.transparent,
              width: selected ? 1.5 : 0,
            ),
          ),
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
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
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 38,
                    child: Align(
                      alignment: Alignment.center,
                      child: Text(
                        entry.title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Spacer(),
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
}
