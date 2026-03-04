import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../controller/me_state.dart';

class WeeklyReportCard extends StatelessWidget {
  const WeeklyReportCard({
    super.key,
    required this.state,
    required this.formatDateTime,
  });

  final MeState state;
  final String Function(DateTime value) formatDateTime;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final averageProgress =
        (state.averageProgress * 100).clamp(0, 100).toStringAsFixed(1);
    final latestOpenedText = state.latestOpenedAt == null
        ? l10n.statsNotAvailable
        : formatDateTime(state.latestOpenedAt!);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.weeklyReportTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatChip(
                  label: l10n.statsTotalBooks,
                  value: '${state.totalBooks}',
                ),
                _StatChip(
                  label: l10n.statsInProgressBooks,
                  value: '${state.inProgressBooks}',
                ),
                _StatChip(
                  label: l10n.statsCompletedBooks,
                  value: '${state.completedBooks}',
                ),
                _StatChip(
                  label: l10n.statsNotStartedBooks,
                  value: '${state.notStartedBooks}',
                ),
                _StatChip(
                  label: l10n.statsAverageProgress,
                  value: '$averageProgress%',
                ),
                _StatChip(
                  label: l10n.statsOpenedIn7Days,
                  value: '${state.booksOpenedInLast7Days}',
                ),
                _StatChip(
                  label: l10n.statsImportedIn7Days,
                  value: '${state.booksImportedInLast7Days}',
                ),
                _StatChip(
                  label: l10n.statsAnnotationsTotal,
                  value: '${state.annotationsCount}',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${l10n.statsLatestOpened}: $latestOpenedText',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '${l10n.statsHighlights}: ${state.highlightsCount}  ·  ${l10n.statsNotes}: ${state.notesCount}  ·  ${l10n.statsBookmarks}: ${state.bookmarksCount}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
