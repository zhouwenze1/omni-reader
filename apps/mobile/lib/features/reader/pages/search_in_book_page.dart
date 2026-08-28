import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation_domain/domain.dart';
import 'package:services_search/services_search.dart';

import '../../../di/repositories_providers.dart';
import '../../../di/services_providers.dart';

class SearchInBookPage extends ConsumerStatefulWidget {
  const SearchInBookPage({super.key, required this.bookUid});

  final String bookUid;

  @override
  ConsumerState<SearchInBookPage> createState() => _SearchInBookPageState();
}

class _SearchInBookPageState extends ConsumerState<SearchInBookPage> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';
  bool _searching = false;
  Object? _fullTextResult;
  String? _fullTextError;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _runSearch(value.trim());
    });
  }

  Future<void> _runSearch(String query) async {
    if (!mounted) return;
    setState(() {
      _query = query.toLowerCase();
      _searching = query.isNotEmpty;
      _fullTextError = null;
      if (query.isEmpty) {
        _fullTextResult = const <SearchHit>[];
      }
    });
    if (query.isEmpty) {
      return;
    }

    try {
      final book = await ref
          .read(_bookProvider(widget.bookUid).future)
          .catchError((_) => null as Book?);
      final result = await ref.read(bookSearchServiceProvider).search(
            bookUid: widget.bookUid,
            format: book?.format,
            query: query,
          );
      if (!mounted) return;
      setState(() {
        _fullTextResult = result;
        _searching = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _fullTextError = '$error';
        _searching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncAnnotations = ref.watch(_annotationsProvider(widget.bookUid));

    return Scaffold(
      appBar: AppBar(title: const Text('书内搜索')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '搜索关键词',
              hintText: '搜索本书正文、笔记、高亮与书签',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: _onQueryChanged,
          ),
          const SizedBox(height: 16),
          if (_searching)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_fullTextError != null) ...[
            const _SectionHeader(title: '正文'),
            Text('搜索失败: $_fullTextError'),
          ] else ...[
            _buildFullTextSection(),
          ],
          const SizedBox(height: 8),
          const _SectionHeader(title: '标注'),
          asyncAnnotations.when(
            loading: () => const SizedBox.shrink(),
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
                return Text(
                  _query.isEmpty ? '本书暂无标注' : '标注中没有匹配内容',
                  style: Theme.of(context).textTheme.bodySmall,
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

  Widget _buildFullTextSection() {
    final result = _fullTextResult;
    if (result is BookSearchUnsupported) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text('本书暂不支持全文搜索'),
          subtitle: Text(
            result.reason == 'format'
                ? '目前仅支持 EPUB 格式的全文搜索。'
                : '未找到本书的原始 EPUB 文件。',
          ),
        ),
      );
    }
    if (result is! List<SearchHit>) {
      return const SizedBox.shrink();
    }

    final hits = result;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: '正文 (${hits.length})'),
        if (hits.isEmpty)
          Text(
            _query.isEmpty ? '输入关键词搜索本书正文' : '正文中没有匹配内容',
            style: Theme.of(context).textTheme.bodySmall,
          )
        else
          ...hits.map(_buildHitTile),
      ],
    );
  }

  Widget _buildHitTile(SearchHit hit) {
    final snippet = hit.snippet;
    // snippet 与 matchOffset 对齐需要考虑前置省略号,偏移由 builder 生成时
    // 已含 "...";直接在显示时用 matchOffset 定位会偏移,这里以纯文本高亮
    // "第一个命中词"近似 —— 通过在渲染前重算词位置。
    final matchIndex = snippet
        .toLowerCase()
        .indexOf(_query.isEmpty ? '' : _query);

    return Card(
      child: ListTile(
        title: matchIndex >= 0 && _query.isNotEmpty
            ? _highlightedSnippet(snippet, matchIndex, _query.length)
            : Text(snippet),
        subtitle: Text(hit.href ?? ''),
        onTap: () => Navigator.of(context).pop(hit),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  Widget _highlightedSnippet(String snippet, int matchIndex, int matchLength) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: snippet.substring(0, matchIndex)),
          TextSpan(
            text: snippet.substring(matchIndex, matchIndex + matchLength),
            style: TextStyle(
              backgroundColor:
                  Theme.of(context).colorScheme.primaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (matchIndex + matchLength < snippet.length)
            TextSpan(text: snippet.substring(matchIndex + matchLength)),
        ],
      ),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall,
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
