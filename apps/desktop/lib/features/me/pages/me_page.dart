import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../di/services_providers.dart';
import '../../../l10n/app_localizations.dart';
import 'package:shared_ui/shared_ui.dart';
import '../controller/me_controller.dart';
import '../widgets/settings_entry_tile.dart';

class MePage extends ConsumerWidget {
  const MePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(meControllerProvider);
    final controller = ref.read(meControllerProvider.notifier);
    final l10n = context.l10n;
    final weekly = ref.watch(weeklyReadingSummaryProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabMe)),
      body: switch (state.status) {
        MePageStatus.loading =>
          const Center(child: CircularProgressIndicator()),
        MePageStatus.error => _buildError(context, state, controller),
        MePageStatus.ready =>
          _buildContent(context, state, controller, weekly, ref),
      },
    );
  }

  Widget _buildError(
    BuildContext context,
    MeState state,
    MeController controller,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.meStatsLoadFailed(state.errorMessage ?? ''),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: controller.refresh,
              child: Text(context.l10n.retry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    MeState state,
    MeController controller,
    WeeklyReadingSummary? weekly,
    WidgetRef ref,
  ) {
    final l10n = context.l10n;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          l10n.weeklySectionTitle,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        WeeklyReportCardV2(
          streakDays: weekly?.streakDays ?? 0,
          weekSeconds: weekly?.weekSeconds ?? 0,
          completedBooks: state.completedBooks,
          notesHighlightsCount: state.highlightsCount + state.notesCount,
          labels: WeeklyReportLabels(
            coreDataTitle: l10n.statsCoreDataTitle,
            streakPrefix: l10n.statsStreakPrefix,
            streakSuffix: l10n.statsStreakSuffix,
            totalTimePrefix: l10n.statsTotalTimePrefix,
            secondaryDataTitle: l10n.statsSecondaryDataTitle,
            finishedBooksLabel: l10n.statsFinishedBooksLabel,
            notesHighlightsLabel: l10n.statsNotesHighlightsLabel,
          ),
          formatDuration: (seconds) => formatReadingDuration(
            seconds,
            (hours, minutes) => hours > 0
                ? l10n.statsHoursMinutes(hours, minutes)
                : l10n.statsMinutes(minutes),
          ),
          onTap: () => context.push(RoutePaths.stats),
        ),
        const SizedBox(height: 12),
        Text(
          l10n.quickSettingsTitle,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        SettingsEntryTile(
          icon: Icons.insights,
          title: l10n.statsCenterTitle,
          onTap: () => context.push(RoutePaths.stats),
        ),
        SettingsEntryTile(
          icon: Icons.settings_outlined,
          title: l10n.appSettings,
          onTap: () => context.push(RoutePaths.appSettings),
        ),
        SettingsEntryTile(
          icon: Icons.sync,
          title: '阅读同步',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  SyncSettingsPage(service: ref.read(syncServiceProvider)),
            ),
          ),
        ),
        SettingsEntryTile(
          icon: Icons.tune,
          title: l10n.readerSettings,
          onTap: () => context.push(RoutePaths.readerSettings),
        ),
        SettingsEntryTile(
          icon: Icons.cloud_outlined,
          title: l10n.cloudSettings,
          onTap: () => context.push(RoutePaths.cloudSettings),
        ),
        SettingsEntryTile(
          icon: Icons.info_outline,
          title: l10n.about,
          onTap: () => context.push(RoutePaths.about),
        ),
        if (state.recentBooks.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            l10n.recentlyOpenedBooks,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          ...state.recentBooks.map(
            (entry) => Card(
              child: ListTile(
                title: Text(entry.title,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  l10n.readingProgress(
                    ((entry.cachedProgress ?? 0) * 100)
                        .clamp(0, 100)
                        .toStringAsFixed(0),
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(RoutePaths.reader(entry.bookUid)),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
