import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation_domain/domain.dart';

import '../../../di/repositories_providers.dart';
import '../../../shared_ui/widgets/empty_view.dart';

class HighlightsPage extends ConsumerWidget {
  const HighlightsPage({super.key, required this.bookUid});

  final String bookUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncAnnotations = ref.watch(_annotationsProvider(bookUid));

    return Scaffold(
      appBar: AppBar(title: const Text('高亮')),
      body: asyncAnnotations.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('加载失败: $error')),
        data: (items) {
          final highlights = items
              .where((item) => item.type == AnnotationType.highlight)
              .toList();
          if (highlights.isEmpty) {
            return const EmptyView(title: '暂无高亮');
          }
          return ListView(
            children: highlights.map((item) {
              return Card(
                child: ListTile(
                  title: Text(item.text ?? '高亮内容'),
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
