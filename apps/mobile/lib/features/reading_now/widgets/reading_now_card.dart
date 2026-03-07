import 'package:flutter/material.dart';
import 'package:foundation_domain/domain.dart';

import '../../../features/library/widgets/book_cover.dart';
import '../../../utils/formatters.dart';

class ReadingNowCard extends StatelessWidget {
  const ReadingNowCard({
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
    final lastReadAt = entry.lastOpenedAt ?? entry.updatedAt;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primaryContainer,
              colorScheme.surface,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: BookCover(
                  filePath: coverPath,
                  width: 118,
                  height: 170,
                  radius: 20,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      entry.authors.isEmpty
                          ? '未知作者'
                          : entry.authors.join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _MetaPill(
                          icon: Icons.history_rounded,
                          label: AppFormatters.relativeReadTime(
                            lastReadAt,
                            locale: Localizations.localeOf(context),
                            withVerb: true,
                          ),
                        ),
                        _MetaPill(
                          icon: Icons.auto_stories_outlined,
                          label: entry.format.toUpperCase(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppFormatters.readingProgress(
                        progress,
                        locale: Localizations.localeOf(context),
                      ),
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.center,
                      child: FilledButton.tonalIcon(
                        onPressed: onTap,
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('继续阅读'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
