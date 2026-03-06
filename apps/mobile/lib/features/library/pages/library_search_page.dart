import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../di/providers.dart';
import '../../../routes/route_paths.dart';

class LibrarySearchPage extends ConsumerStatefulWidget {
  const LibrarySearchPage({super.key});

  @override
  ConsumerState<LibrarySearchPage> createState() => _LibrarySearchPageState();
}

class _LibrarySearchPageState extends ConsumerState<LibrarySearchPage> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncLibrary = ref.watch(libraryIndexProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('搜索书架')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: '按标题、作者或格式搜索',
              ),
              onChanged: (value) {
                setState(() {
                  _query = value.trim().toLowerCase();
                });
              },
            ),
          ),
          Expanded(
            child: asyncLibrary.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('加载失败: $error')),
              data: (items) {
                final filtered = _query.isEmpty
                    ? items
                    : items.where((item) {
                        final text = [
                          item.title,
                          item.authors.join(' '),
                          item.format,
                        ].join(' ').toLowerCase();
                        return text.contains(_query);
                      }).toList();
                if (filtered.isEmpty) {
                  return const Center(child: Text('没有匹配的书籍'));
                }
                return ListView(
                  children: filtered.map((item) {
                    return Card(
                      child: ListTile(
                        title: Text(item.title),
                        subtitle: Text(item.authors.join(', ').isEmpty
                            ? item.format
                            : '${item.authors.join(', ')} · ${item.format.toUpperCase()}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push(RoutePaths.reader(item.bookUid)),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
