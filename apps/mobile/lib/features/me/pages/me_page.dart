import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:shared_ui/shared_ui.dart';
import '../../../utils/formatters.dart';
import '../../import_center/pages/import_center_page.dart';
import '../controller/me_controller.dart';
import 'stats_detail_page.dart';
import '../widgets/settings_entry_tile.dart';
import '../widgets/weekly_report_card.dart';

class MePage extends ConsumerWidget {
  const MePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(meControllerProvider);
    final controller = ref.read(meControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: switch (state.status) {
        MePageStatus.loading =>
          const Center(child: CircularProgressIndicator()),
        MePageStatus.error => _buildError(state, controller),
        MePageStatus.ready => _buildContent(context, state),
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

  Widget _buildContent(BuildContext context, MeState state) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        WeeklyReportCard(state: state),
        const SizedBox(height: 12),
        Text(
          '快捷入口',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
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
          icon: Icons.insights_outlined,
          title: '统计详情',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => StatsDetailPage(state: state),
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
