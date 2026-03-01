import '../index/search_index.dart';
import '../models.dart';
import '../segmenter.dart';

class SearchIndexBuilder {
  SearchIndexBuilder({
    required SearchIndex index,
    ParagraphSegmenter segmenter = const ParagraphSegmenter(),
  })  : _index = index,
        _segmenter = segmenter;

  final SearchIndex _index;
  final ParagraphSegmenter _segmenter;

  Future<void> buildFromChapters({
    required String bookId,
    required List<ChapterText> chapters,
    int minParagraphLength = 2,
  }) async {
    final paragraphs = <ParagraphRecord>[];

    for (final chapter in chapters) {
      final segmented = _segmenter.segment(
        chapter.text,
        minParagraphLength: minParagraphLength,
      );
      for (var paraIndex = 0; paraIndex < segmented.length; paraIndex++) {
        paragraphs.add(
          ParagraphRecord(
            bookId: bookId,
            spineIndex: chapter.spineIndex,
            href: chapter.href,
            cfi: chapter.cfi,
            paraIndex: paraIndex,
            text: segmented[paraIndex],
          ),
        );
      }
    }

    await _index.upsertParagraphs(bookId, paragraphs);
  }
}
