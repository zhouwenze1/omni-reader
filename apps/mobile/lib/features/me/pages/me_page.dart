import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:shared_ui/shared_ui.dart';
import '../../../di/services_providers.dart';
import '../../../l10n/l10n.dart';
import '../../../utils/formatters.dart';
import '../../import_center/pages/import_center_page.dart';
import '../controller/me_controller.dart';
import '../widgets/settings_entry_tile.dart';

class MePage extends ConsumerWidget {
  const MePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(meControllerProvider);
    final controller = ref.read(meControllerProvider.notifier);
    final weekly = ref.watch(weeklyReadingSummaryProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: switch (state.status) {
        MePageStatus.loading =>
          const Center(child: CircularProgressIndicator()),
        MePageStatus.error => _buildError(state, controller),
        MePageStatus.ready => _buildContent(context, state, weekly, ref),
      },
    );
  }

  Widget _buildError(MeState state, MeController controller) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(state.errorMessage ?? '加载失败'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: controller.refresh,
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    MeState state,
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
          '快捷入口',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        SettingsEntryTile(
          icon: Icons.insights,
          title: l10n.statsCenterEntry,
          onTap: () => context.push(RoutePaths.stats),
        ),
        SettingsEntryTile(
          icon: Icons.file_upload_outlined,
          title: '导入中心',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ImportCenterPage(),
              ),
            );
          },
        ),
        SettingsEntryTile(
          icon: Icons.settings_outlined,
          title: '应用设置',
          onTap: () => context.push(RoutePaths.appSettings),
        ),
        SettingsEntryTile(
          icon: Icons.tune,
          title: '阅读器设置',
          onTap: () => context.push(RoutePaths.readerSettings),
        ),
        SettingsEntryTile(
          icon: Icons.cloud_outlined,
          title: '云端设置',
          onTap: () => context.push(RoutePaths.cloudSettings),
        ),
        SettingsEntryTile(
          icon: Icons.info_outline,
          title: '关于软件',
          onTap: () => context.push(RoutePaths.about),
        ),
        if (state.recentBooks.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            '最近打开',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          ...state.recentBooks.map(
            (entry) => Card(
              child: ListTile(
                title: Text(
                  entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '进度 ${AppFormatters.percent(entry.cachedProgress ?? 0)}',
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
