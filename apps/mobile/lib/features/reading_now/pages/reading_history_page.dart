import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation_domain/domain.dart';
import 'package:go_router/go_router.dart';

import '../../../di/providers.dart';
import '../../../routes/route_paths.dart';
import '../../../shared_ui/widgets/empty_view.dart';
import '../../../utils/formatters.dart';

class ReadingHistoryPage extends ConsumerWidget {
  const ReadingHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncLibrary = ref.watch(libraryIndexProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('阅读历史')),
      body: asyncLibrary.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('加载失败: $error')),
        data: (items) {
          final activeItems = items.where(_hasReadingActivity).toList();
          final sorted = [...activeItems]..sort(
              (a, b) => (b.lastOpenedAt ?? b.updatedAt).compareTo(
                a.lastOpenedAt ?? a.updatedAt,
              ),
            );
          if (sorted.isEmpty) {
            return const EmptyView(
              title: '暂无历史记录',
              message: '开始阅读后，这里会按最近打开时间整理记录。',
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: sorted.map((item) {
              final time = item.lastOpenedAt ?? item.updatedAt;
              return Card(
                child: ListTile(
                  title: Text(item.title),
                  subtitle: Text(
                    '最近阅读 ${AppFormatters.dateTime(time)} · ${AppFormatters.percent(item.cachedProgress ?? 0)}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(RoutePaths.reader(item.bookUid)),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  bool _hasReadingActivity(LibraryIndexEntry entry) {
    final progress = (entry.cachedProgress ?? 0).clamp(0.0, 1.0);
    return entry.lastOpenedAt != null ||
        progress > libraryProgressStartedThreshold;
  }
}
