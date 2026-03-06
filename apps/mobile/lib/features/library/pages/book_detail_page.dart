import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controller/book_detail_controller.dart';

class BookDetailPage extends ConsumerWidget {
  const BookDetailPage({super.key, required this.bookUid});

  final String bookUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncBook = ref.watch(mobileBookDetailProvider(bookUid));

    return Scaffold(
      appBar: AppBar(title: const Text('书籍详情')),
      body: asyncBook.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('加载失败: $error')),
        data: (book) {
          if (book == null) {
            return const Center(child: Text('书籍不存在'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  title: const Text('标题'),
                  subtitle: Text(book.title),
                ),
              ),
              Card(
                child: ListTile(
                  title: const Text('格式'),
                  subtitle: Text(book.format),
                ),
              ),
              Card(
                child: ListTile(
                  title: const Text('作者'),
                  subtitle: Text(book.authors.join(', ').isEmpty
                      ? '未知'
                      : book.authors.join(', ')),
                ),
              ),
              Card(
                child: ListTile(
                  title: const Text('路径'),
                  subtitle: Text(book.rootDir),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
