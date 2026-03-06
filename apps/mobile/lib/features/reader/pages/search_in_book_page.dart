import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation_domain/domain.dart';

import '../../../di/repositories_providers.dart';

class SearchInBookPage extends ConsumerStatefulWidget {
  const SearchInBookPage({super.key, required this.bookUid});

  final String bookUid;

  @override
  ConsumerState<SearchInBookPage> createState() => _SearchInBookPageState();
}

class _SearchInBookPageState extends ConsumerState<SearchInBookPage> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncBook = ref.watch(_bookProvider(widget.bookUid));
    final asyncAnnotations = ref.watch(_annotationsProvider(widget.bookUid));

    return Scaffold(
      appBar: AppBar(title: const Text('书内搜索')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              labelText: '搜索关键词',
              hintText: '当前先搜索本书笔记、高亮文本与书签说明',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) {
              setState(() {
                _query = value.trim().toLowerCase();
              });
            },
          ),
          const SizedBox(height: 16),
          asyncBook.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (book) => Card(
              child: ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(book?.title ?? widget.bookUid),
                subtitle: Text(
                  '移动端全文搜索索引尚未接入；当前提供本书标注内容的本地搜索。',
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          asyncAnnotations.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Text('加载标注失败: $error'),
            data: (annotations) {
              final filtered = _query.isEmpty
                  ? annotations
                  : annotations.where((annotation) {
                      final haystack = [
                        annotation.text ?? '',
                        annotation.note ?? '',
                        annotation.locator.text ?? '',
                        annotation.locator.href ?? '',
                      ].join('\n').toLowerCase();
                      return haystack.contains(_query);
                    }).toList();

              if (filtered.isEmpty) {
                return const Card(
                  child: ListTile(
                    leading: Icon(Icons.search_off_outlined),
                    title: Text('没有匹配内容'),
                  ),
                );
              }

              return Column(
                children: filtered.map((annotation) {
                  return Card(
                    child: ListTile(
                      title: Text(annotation.text?.trim().isNotEmpty == true
                          ? annotation.text!
                          : annotation.note?.trim().isNotEmpty == true
                              ? annotation.note!
                              : '无文本内容'),
                      subtitle: Text(
                        '类型: ${annotation.type.name}  ·  ${annotation.locator.href ?? '未知位置'}',
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

final _bookProvider = FutureProvider.family<Book?, String>((ref, bookUid) {
  return ref.watch(bookRepositoryProvider).getBook(bookUid);
});

final _annotationsProvider =
    FutureProvider.family<List<Annotation>, String>((ref, bookUid) {
  return ref.watch(annotationRepositoryProvider).listAnnotations(bookUid);
});
