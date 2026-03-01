import 'dart:typed_data';

import 'builder/index_builder.dart';
import 'epub/epub_text_extractor.dart';
import 'index/memory_index.dart';
import 'index/search_index.dart';
import 'models.dart';
import 'segmenter.dart';

class EpubSearchService {
  factory EpubSearchService({
    SearchIndex? index,
    ParagraphSegmenter segmenter = const ParagraphSegmenter(),
    ChapterTextSource? chapterTextSource,
  }) {
    final resolvedIndex = index ?? MemorySearchIndex();
    return EpubSearchService._(
      index: resolvedIndex,
      chapterTextSource: chapterTextSource ?? const EpubTextExtractor(),
      builder: SearchIndexBuilder(index: resolvedIndex, segmenter: segmenter),
    );
  }

  EpubSearchService._({
    required this.index,
    required this.chapterTextSource,
    required SearchIndexBuilder builder,
  }) : _builder = builder;

  final SearchIndex index;
  final ChapterTextSource chapterTextSource;
  final SearchIndexBuilder _builder;

  Future<void> ensureIndexedFromEpubBytes({
    required String bookId,
    required Uint8List epubBytes,
    bool forceRebuild = false,
  }) async {
    final indexed = await index.hasIndex(bookId);
    if (indexed && !forceRebuild) {
      return;
    }

    final chapters = await chapterTextSource.readChapters(epubBytes);
    await _builder.buildFromChapters(bookId: bookId, chapters: chapters);
  }

  Future<void> ensureIndexedFromChapters({
    required String bookId,
    required List<ChapterText> chapters,
    bool forceRebuild = false,
  }) async {
    final indexed = await index.hasIndex(bookId);
    if (indexed && !forceRebuild) {
      return;
    }
    await _builder.buildFromChapters(bookId: bookId, chapters: chapters);
  }

  Future<List<SearchHit>> search(
    SearchQuery searchQuery, {
    Uint8List? epubBytes,
    bool includeParagraphText = false,
  }) async {
    if (!(await index.hasIndex(searchQuery.bookId))) {
      if (epubBytes == null) {
        throw ArgumentError(
          'No index for bookId=${searchQuery.bookId}. '
          'Provide epubBytes or call ensureIndexedFromChapters first.',
        );
      }
      await ensureIndexedFromEpubBytes(
        bookId: searchQuery.bookId,
        epubBytes: epubBytes,
      );
    }

    final matches = await index.search(
      searchQuery.bookId,
      searchQuery.query,
      limit: searchQuery.limit,
      caseSensitive: searchQuery.caseSensitive,
    );

    return matches
        .map(
          (match) => SearchHit(
            bookId: searchQuery.bookId,
            spineIndex: match.paragraph.spineIndex,
            chapterIndex: match.paragraph.chapterIndex,
            href: match.paragraph.href,
            paraIndex: match.paragraph.paraIndex,
            snippet: _buildSnippet(
              match.paragraph.text,
              match.matchOffset,
              match.matchLength,
              searchQuery.contextChars,
            ),
            matchOffset: match.matchOffset,
            matchLength: match.matchLength,
            cfi: _buildHitCfi(match.paragraph, match.matchOffset),
            paragraphText: includeParagraphText ? match.paragraph.text : null,
          ),
        )
        .toList(growable: false);
  }

  String _buildSnippet(
    String paragraphText,
    int matchOffset,
    int matchLength,
    int contextChars,
  ) {
    final left = (matchOffset - contextChars).clamp(0, paragraphText.length);
    final right = (matchOffset + matchLength + contextChars).clamp(
      0,
      paragraphText.length,
    );

    final prefix = left > 0 ? '...' : '';
    final suffix = right < paragraphText.length ? '...' : '';
    return '$prefix${paragraphText.substring(left, right)}$suffix';
  }

  String _buildHitCfi(ParagraphRecord paragraph, int matchOffset) {
    final spineStep = (paragraph.spineIndex + 1) * 2;
    final paragraphStep = (paragraph.paraIndex + 1) * 2;
    final safeOffset = matchOffset.clamp(0, paragraph.text.length);

    // Use a standard EPUB CFI layout so web readers can consume it directly.
    return 'epubcfi(/6/$spineStep!/4/$paragraphStep/1:$safeOffset)';
  }
}
