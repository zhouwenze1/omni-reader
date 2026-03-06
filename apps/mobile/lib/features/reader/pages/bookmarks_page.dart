import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation_domain/domain.dart';

import '../../../di/repositories_providers.dart';
import '../../../shared_ui/widgets/empty_view.dart';

class BookmarksPage extends ConsumerWidget {
  const BookmarksPage({super.key, required this.bookUid});

  final String bookUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncAnnotations = ref.watch(_annotationsProvider(bookUid));

    return Scaffold(
      appBar: AppBar(title: const Text('书签')),
      body: asyncAnnotations.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('加载失败: $error')),
        data: (items) {
          final bookmarks = items
              .where((item) => item.type == AnnotationType.bookmark)
              .toList();
          if (bookmarks.isEmpty) {
            return const EmptyView(title: '暂无书签');
          }
          return ListView(
            children: bookmarks.map((item) {
              return Card(
                child: ListTile(
                  title: Text(item.locator.text ?? '书签位置'),
                  subtitle: Text(item.locator.href ?? '未知章节'),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

final _annotationsProvider =
    FutureProvider.family<List<Annotation>, String>((ref, bookUid) {
  return ref.watch(annotationRepositoryProvider).listAnnotations(bookUid);
});
