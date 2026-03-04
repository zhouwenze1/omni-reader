import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../../../routes/route_paths.dart';
import '../controller/me_controller.dart';
import '../controller/me_state.dart';
import '../widgets/settings_entry_tile.dart';
import '../widgets/weekly_report_card.dart';

class MePage extends ConsumerWidget {
  const MePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(meControllerProvider);
    final controller = ref.read(meControllerProvider.notifier);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabMe)),
      body: switch (state.status) {
        MePageStatus.loading =>
          const Center(child: CircularProgressIndicator()),
        MePageStatus.error => _buildError(context, state, controller),
        MePageStatus.ready => _buildContent(context, state, controller),
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
  ) {
    final l10n = context.l10n;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        WeeklyReportCard(
          state: state,
          formatDateTime: (value) {
            final localeTag = Localizations.localeOf(context).toLanguageTag();
            return DateFormat('yyyy-MM-dd HH:mm', localeTag).format(value);
          },
        ),
        const SizedBox(height: 12),
        Text(
          l10n.quickSettingsTitle,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        SettingsEntryTile(
          icon: Icons.settings_outlined,
          title: l10n.appSettings,
          onTap: () => context.push(RoutePaths.appSettings),
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
