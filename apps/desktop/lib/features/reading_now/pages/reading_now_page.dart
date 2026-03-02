import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../di/providers.dart';
import '../../../routes/route_paths.dart';
import '../../../shared_ui/widgets/empty_view.dart';
import '../../../shared_ui/widgets/error_view.dart';
import '../../../shared_ui/widgets/loading_view.dart';

class ReadingNowPage extends ConsumerWidget {
  const ReadingNowPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncLibrary = ref.watch(libraryIndexProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('阅读中')),
      body: asyncLibrary.when(
        loading: () => const LoadingView(label: '加载阅读记录...'),
        error: (error, _) => ErrorView(
          title: '加载失败',
          message: '$error',
          onRetry: () => ref.invalidate(libraryIndexProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyView(
              title: '暂无在读书籍',
              message: '先去书架导入一本书开始阅读。',
            );
          }

          final sorted = [...items]
            ..sort((a, b) => (b.lastOpenedAt ?? b.updatedAt)
                .compareTo(a.lastOpenedAt ?? a.updatedAt));

          return ListView.builder(
            itemCount: sorted.length,
            itemBuilder: (context, index) {
              final item = sorted[index];
              final progress = ((item.cachedProgress ?? 0) * 100).toStringAsFixed(0);
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  title: Text(item.title),
                  subtitle: Text('最近阅读 · $progress%'),
                  trailing: FilledButton(
                    onPressed: () => context.push(RoutePaths.reader(item.bookUid)),
                    child: const Text('继续'),
                  ),
                  onTap: () => context.push(RoutePaths.reader(item.bookUid)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
