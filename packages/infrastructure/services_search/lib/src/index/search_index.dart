import '../models.dart';

class ParagraphMatch {
  const ParagraphMatch({
    required this.paragraph,
    required this.matchOffset,
    required this.matchLength,
  });

  final ParagraphRecord paragraph;
  final int matchOffset;
  final int matchLength;
}

abstract class SearchIndex {
  Future<bool> hasIndex(String bookId);

  Future<void> deleteIndex(String bookId);

  Future<void> upsertParagraphs(
      String bookId, List<ParagraphRecord> paragraphs);

  Future<List<ParagraphMatch>> search(
    String bookId,
    String query, {
    int limit = 20,
    bool caseSensitive = false,
  });
}
