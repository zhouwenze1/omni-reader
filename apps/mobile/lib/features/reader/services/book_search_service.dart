import 'dart:io';
import 'dart:isolate';

import 'package:infrastructure_data/data.dart';
import 'package:services_search/services_search.dart';

/// 现算式书内全文搜索:首次查询时读取书的原始 EPUB,在后台 isolate 中
/// 提取章节文本并建立内存索引,会话内复用;跨会话不持久化(持久索引为
/// 后续的预建开关功能)。
class BookSearchService {
  BookSearchService({required StoragePaths storagePaths})
      : _storagePaths = storagePaths;

  final StoragePaths _storagePaths;

  final Map<String, EpubSearchService> _sessionIndexes =
      <String, EpubSearchService>{};

  /// 返回 `List<SearchHit>`;`BookSearchUnsupported` 表示该书不可搜索
  /// (非 EPUB 或原始文件缺失)。
  Future<Object> search({
    required String bookUid,
    String? format,
    required String query,
    int limit = 50,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return const <SearchHit>[];
    }
    if (format != null && format != 'epub') {
      return const BookSearchUnsupported(reason: 'format');
    }

    final epubPath =
        '${_storagePaths.booksRoot.path}/$bookUid/book.epub';
    if (!File(epubPath).existsSync()) {
      return const BookSearchUnsupported(reason: 'missing-file');
    }

    final service = await _ensureIndexed(bookUid, epubPath);
    return service.search(
      SearchQuery(
        bookId: bookUid,
        query: trimmed,
        limit: limit,
        contextChars: 24,
      ),
      includeParagraphText: true,
    );
  }

  Future<EpubSearchService> _ensureIndexed(
    String bookUid,
    String epubPath,
  ) async {
    final existing = _sessionIndexes[bookUid];
    if (existing != null) {
      return existing;
    }

    // 提取 + 建索引在后台 isolate 完成,避免大书卡 UI。
    final created = await Isolate.run(() {
      return _buildIndex(bookUid, epubPath);
    });
    _sessionIndexes[bookUid] = created;
    return created;
  }
}

/// isolate 入口:必须为顶层/静态函数。
Future<EpubSearchService> _buildIndex(String bookUid, String epubPath) async {
  final bytes = await File(epubPath).readAsBytes();
  final service = EpubSearchService();
  await service.ensureIndexedFromEpubBytes(bookId: bookUid, epubBytes: bytes);
  return service;
}

/// 全文搜索不可用的原因。
class BookSearchUnsupported {
  const BookSearchUnsupported({required this.reason});

  /// 'format' = 非 EPUB 格式;'missing-file' = 原始 EPUB 文件缺失。
  final String reason;
}
