import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../di/providers.dart';
import '../../../routes/route_paths.dart';
import '../../../shared_ui/widgets/empty_view.dart';
import '../../../shared_ui/widgets/error_view.dart';
import '../../../shared_ui/widgets/loading_view.dart';
import 'reading_history_page.dart';
import '../widgets/reading_now_card.dart';
import '../widgets/recent_item_tile.dart';

class ReadingNowPage extends ConsumerWidget {
  const ReadingNowPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncLibrary = ref.watch(libraryIndexProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('阅读中'),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ReadingHistoryPage(),
              ),
            ),
            icon: const Icon(Icons.history),
          ),
        ],
      ),
      body: asyncLibrary.when(
        loading: () => const LoadingView(label: '正在加载阅读记录'),
        error: (error, _) => ErrorView(
          title: '加载失败',
          message: '$error',
          onRetry: () => ref.invalidate(libraryIndexProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyView(
              title: '暂无在读书籍',
              message: '先去书架导入一本书，或打开最近导入的内容开始阅读。',
            );
          }

          final sorted = [...items]..sort(
              (a, b) => (b.lastOpenedAt ?? b.updatedAt).compareTo(
                a.lastOpenedAt ?? a.updatedAt,
              ),
            );

          return ListView(
            children: [
              for (final item in sorted.take(3))
                ReadingNowCard(
                  entry: item,
                  onTap: () => context.push(RoutePaths.reader(item.bookUid)),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Text(
                  '最近记录',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              for (final item in sorted.skip(3))
                RecentItemTile(
                  entry: item,
                  onTap: () => context.push(RoutePaths.reader(item.bookUid)),
                ),
            ],
          );
        },
      ),
    );
  }
}
