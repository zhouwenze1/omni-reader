import '../models.dart';
import 'search_index.dart';

class MemorySearchIndex implements SearchIndex {
  final Map<String, List<ParagraphRecord>> _store =
      <String, List<ParagraphRecord>>{};

  @override
  Future<bool> hasIndex(String bookId) async => _store.containsKey(bookId);

  @override
  Future<void> deleteIndex(String bookId) async {
    _store.remove(bookId);
  }

  @override
  Future<void> upsertParagraphs(
      String bookId, List<ParagraphRecord> paragraphs) async {
    _store[bookId] = List<ParagraphRecord>.unmodifiable(paragraphs);
  }

  @override
  Future<List<ParagraphMatch>> search(
    String bookId,
    String query, {
    int limit = 20,
    bool caseSensitive = false,
  }) async {
    if (query.isEmpty || limit <= 0) {
      return const <ParagraphMatch>[];
    }

    final paragraphs = _store[bookId];
    if (paragraphs == null || paragraphs.isEmpty) {
      return const <ParagraphMatch>[];
    }

    final needle = caseSensitive ? query : query.toLowerCase();
    final matches = <ParagraphMatch>[];

    for (final paragraph in paragraphs) {
      final haystack =
          caseSensitive ? paragraph.text : paragraph.text.toLowerCase();
      var from = 0;
      while (from < haystack.length) {
        final idx = haystack.indexOf(needle, from);
        if (idx < 0) {
          break;
        }
        matches.add(
          ParagraphMatch(
            paragraph: paragraph,
            matchOffset: idx,
            matchLength: query.length,
          ),
        );
        if (matches.length >= limit) {
          return matches;
        }
        from = idx + needle.length;
      }
    }

    return matches;
  }
}
