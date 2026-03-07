import 'package:flutter/material.dart';
import 'package:foundation_domain/domain.dart';

import '../../library/widgets/book_cover.dart';
import '../../../utils/formatters.dart';

class RecentItemTile extends StatelessWidget {
  const RecentItemTile({
    super.key,
    required this.entry,
    required this.coverPath,
    required this.onTap,
  });

  final LibraryIndexEntry entry;
  final String? coverPath;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final progress = (entry.cachedProgress ?? 0).clamp(0.0, 1.0);
    final lastReadText = AppFormatters.relativeReadTime(
      entry.lastOpenedAt ?? entry.updatedAt,
      locale: Localizations.localeOf(context),
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Ink(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.22),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              BookCover(
                filePath: coverPath,
                width: 58,
                height: 82,
                radius: 14,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.authors.isEmpty
                          ? entry.format.toUpperCase()
                          : entry.authors.join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      lastReadText,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
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
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.tonal(
                onPressed: onTap,
                child: const Text('继续'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
