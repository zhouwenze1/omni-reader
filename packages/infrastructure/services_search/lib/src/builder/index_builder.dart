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
      final segments = chapter.segments;
      if (segments != null) {
        // DOM 对齐路径:一段一条记录,携带段级 CFI 路径与文本节点锚点。
        for (var paraIndex = 0; paraIndex < segments.length; paraIndex++) {
          final segment = segments[paraIndex];
          paragraphs.add(
            ParagraphRecord(
              bookId: bookId,
              spineIndex: chapter.spineIndex,
              href: chapter.href,
              cfi: chapter.cfi,
              cfiPath: segment.cfiPath,
              anchors: segment.anchors,
              paraIndex: paraIndex,
              text: segment.text,
            ),
          );
        }
        continue;
      }

      // 回退路径:原始 HTML 按行分段(近似 CFI)。
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
