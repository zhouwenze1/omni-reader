import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../di/providers.dart';
import '../../../routes/route_paths.dart';

class ReadingNowPage extends ConsumerWidget {
  const ReadingNowPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncLibrary = ref.watch(libraryIndexProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('阅读中')),
      body: asyncLibrary.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('加载失败: $error')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('暂无在读书籍')); 
          }
          final sorted = [...items]
            ..sort((a, b) => (b.lastOpenedAt ?? b.updatedAt)
                .compareTo(a.lastOpenedAt ?? a.updatedAt));
          return ListView.builder(
            itemCount: sorted.length,
            itemBuilder: (context, index) {
              final item = sorted[index];
              final progress = ((item.cachedProgress ?? 0) * 100).toStringAsFixed(0);
              return ListTile(
                title: Text(item.title),
                subtitle: Text('阅读进度 $progress%'),
                trailing: FilledButton(
                  onPressed: () => context.push(RoutePaths.reader(item.bookUid)),
                  child: const Text('继续'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
