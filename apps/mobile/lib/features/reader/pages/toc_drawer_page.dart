import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation_domain/domain.dart';

import '../../../di/repositories_providers.dart';
import 'package:shared_ui/shared_ui.dart';
import '../../../shared_ui/widgets/error_view.dart';

class TocDrawerPage extends ConsumerWidget {
  const TocDrawerPage({super.key, required this.bookUid});

  final String bookUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tocFuture = ref.watch(_tocProvider(bookUid));
    final currentHref = ref.watch(readerCurrentHrefProvider(bookUid));

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

          return ReaderTocList(
            items: items,
            currentHref: currentHref,
            onSelect: (item) => Navigator.of(context).pop(item),
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
