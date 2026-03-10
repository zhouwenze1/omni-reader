import 'package:flutter/material.dart';
import 'package:foundation_domain/domain.dart';

import '../../../utils/formatters.dart';
import 'book_cover.dart';

class BookGridItem extends StatelessWidget {
  const BookGridItem({
    super.key,
    required this.entry,
    required this.coverPath,
    required this.selectionMode,
    required this.multiSelected,
    required this.onTap,
    this.onLongPress,
  });

  final LibraryIndexEntry entry;
  final String? coverPath;
  final bool selectionMode;
  final bool multiSelected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final progress = (entry.cachedProgress ?? 0).clamp(0.0, 1.0);
    final authorText = entry.authors.isEmpty
        ? entry.format.toUpperCase()
        : entry.authors.join(' · ');

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(24),
      child: Ink(
        decoration: BoxDecoration(
          color: multiSelected
              ? colorScheme.primaryContainer
              : colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: multiSelected
                ? colorScheme.primary.withValues(alpha: 0.45)
                : colorScheme.outlineVariant.withValues(alpha: 0.24),
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Align(
                      child: BookCover(
                        filePath: coverPath,
                        width: 122,
                        height: 172,
                        radius: 16,
                      ),
                    ),
                    Positioned(
                      left: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          entry.format.toUpperCase(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    if (selectionMode)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: colorScheme.surface.withValues(alpha: 0.94),
                            shape: BoxShape.circle,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: Icon(
                              multiSelected
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              size: 22,
                              color: multiSelected
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                entry.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                authorText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                AppFormatters.readingProgress(
                  progress,
                  locale: Localizations.localeOf(context),
                ),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
