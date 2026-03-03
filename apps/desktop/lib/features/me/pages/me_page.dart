import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../di/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../../routes/route_paths.dart';

class MePage extends ConsumerWidget {
  const MePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncLibrary = ref.watch(libraryIndexProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.tabMe)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: asyncLibrary.when(
                loading: () => const Text('统计加载中...'),
                error: (error, _) => Text('统计加载失败: $error'),
                data: (items) {
                  final done = items
                      .where((e) => (e.cachedProgress ?? 0) >= 0.98)
                      .length;
                  final notes = 0;
                  final highlights = 0;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('本周周报',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Text('在读书籍: ${items.length}'),
                      Text('已完成书籍: $done'),
                      Text('笔记/高亮: ${notes + highlights}'),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 10),
          _entry(
            context,
            icon: Icons.settings,
            title: context.l10n.settings,
            path: RoutePaths.settingsHome,
          ),
        ],
      ),
    );
  }

  Widget _entry(BuildContext context,
      {required IconData icon, required String title, required String path}) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push(path),
      ),
    );
  }
}
