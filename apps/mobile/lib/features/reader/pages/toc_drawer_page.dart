import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation_domain/domain.dart';

import '../../../di/repositories_providers.dart';
import '../../../shared_ui/widgets/empty_view.dart';
import '../../../shared_ui/widgets/error_view.dart';
import '../../../shared_ui/widgets/loading_view.dart';

class TocDrawerPage extends ConsumerWidget {
  const TocDrawerPage({super.key, required this.bookUid});

  final String bookUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tocFuture = ref.watch(_tocProvider(bookUid));

    return Scaffold(
      appBar: AppBar(title: const Text('目录')),
      body: tocFuture.when(
        loading: () => const LoadingView(label: '正在加载目录'),
        error: (error, _) => ErrorView(
          title: '目录加载失败',
          message: '$error',
          onRetry: () => ref.invalidate(_tocProvider(bookUid)),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyView(
              title: '暂无目录数据',
              message: '这本书当前还没有缓存目录信息。',
            );
          }

          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                contentPadding: EdgeInsets.only(
                  left: 16 + (item.level * 16),
                  right: 16,
                ),
                title: Text(item.title),
                trailing: item.href == null
                    ? null
                    : const Icon(Icons.chevron_right),
                onTap: item.href == null
                    ? null
                    : () => Navigator.of(context).pop(item),
              );
            },
          );
        },
      ),
    );
  }
}

final _tocProvider =
    FutureProvider.family<List<TocItem>, String>((ref, bookUid) {
  return ref.watch(tocRepositoryProvider).getToc(bookUid);
});
