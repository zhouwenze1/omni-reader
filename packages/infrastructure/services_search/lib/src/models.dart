import 'dart:typed_data';

class SearchQuery {
  const SearchQuery({
    required this.bookId,
    required this.query,
    this.limit = 20,
    this.contextChars = 40,
    this.caseSensitive = false,
  });

  final String bookId;
  final String query;
  final int limit;
  final int contextChars;
  final bool caseSensitive;
}

class SearchHit {
  const SearchHit({
    required this.bookId,
    required this.spineIndex,
    int? chapterIndex,
    required this.paraIndex,
    this.href,
    required this.snippet,
    required this.matchOffset,
    required this.matchLength,
    this.cfi,
    this.paragraphText,
  }) : chapterIndex = chapterIndex ?? spineIndex;

  final String bookId;
  final int spineIndex;
  final int chapterIndex;
  final String? href;
  final int paraIndex;
  final String snippet;
  final int matchOffset;
  final int matchLength;
  final String? cfi;
  final String? paragraphText;
}

class ChapterText {
  const ChapterText({
    required this.spineIndex,
    this.href,
    this.cfi,
    required this.text,
  });

  final int spineIndex;
  final String? href;
  final String? cfi;
  final String text;
}

class ParagraphRecord {
  const ParagraphRecord({
    required this.bookId,
    required this.spineIndex,
    int? chapterIndex,
    this.href,
    this.cfi,
    required this.paraIndex,
    required this.text,
  }) : chapterIndex = chapterIndex ?? spineIndex;

  final String bookId;
  final int spineIndex;
  final int chapterIndex;
  final String? href;
  final String? cfi;
  final int paraIndex;
  final String text;
}

abstract class ChapterTextSource {
  Future<List<ChapterText>> readChapters(Uint8List epubBytes);
}
