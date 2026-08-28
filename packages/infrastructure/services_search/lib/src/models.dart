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

/// A text node inside a chapter, mapped from its position in the normalized
/// paragraph text back to the DOM.
///
/// [start] is the character index (within the paragraph's normalized text)
/// where this text node begins; [path] is the chapter-local CFI terminal path
/// to the text node (element steps `(childIndex + 1) * 2`, text steps
/// `textChildIndex * 2 + 1`, e.g. `/2/6/3`), matching the renderer's
/// `resolvePointFromCfi` walk over the paginated chapter body.
class DomTextAnchor {
  const DomTextAnchor({
    required this.start,
    required this.path,
    this.rawAdjust = 0,
  });

  /// Character index within the paragraph's normalized text where this text
  /// node's first kept character lands.
  final int start;

  /// Chapter-local CFI terminal path to the text node.
  final String path;

  /// Raw characters collapsed (whitespace runs) before the first kept
  /// character, so `localOffset = matchOffset - start + rawAdjust` lands in
  /// the raw DOM text node data.
  final int rawAdjust;
}

/// A single block-level element inside a chapter, aligned with the DOM the
/// renderer paginates.
///
/// [cfiPath] is the chapter-local CFI element path from the chapter body to
/// the element. [anchors] maps positions in [text] back to exact DOM text
/// nodes so a match offset can produce a precise CFI terminal.
class ChapterSegment {
  const ChapterSegment({
    required this.text,
    required this.cfiPath,
    required this.anchors,
  });

  final String text;
  final String cfiPath;
  final List<DomTextAnchor> anchors;
}

class ChapterText {
  const ChapterText({
    required this.spineIndex,
    this.href,
    this.cfi,
    required this.text,
    this.segments,
  });

  final int spineIndex;
  final String? href;
  final String? cfi;
  final String text;

  /// DOM-aligned segments. When present, the index builder uses them directly
  /// (one paragraph per segment, with per-segment CFI); when null, the builder
  /// falls back to [ParagraphSegmenter] line-based segmentation.
  final List<ChapterSegment>? segments;
}

class ParagraphRecord {
  const ParagraphRecord({
    required this.bookId,
    required this.spineIndex,
    int? chapterIndex,
    this.href,
    this.cfi,
    this.cfiPath,
    this.anchors,
    required this.paraIndex,
    required this.text,
  }) : chapterIndex = chapterIndex ?? spineIndex;

  final String bookId;
  final int spineIndex;
  final int chapterIndex;
  final String? href;
  final String? cfi;

  /// Chapter-local CFI element path for this paragraph (e.g. `/2/6`), present
  /// only for DOM-aligned paragraphs.
  final String? cfiPath;

  /// Per-text-node anchors for mapping a match offset inside [text] onto an
  /// exact CFI terminal; empty/null for line-segmented fallback paragraphs.
  final List<DomTextAnchor>? anchors;

  final int paraIndex;
  final String text;
}

abstract class ChapterTextSource {
  Future<List<ChapterText>> readChapters(Uint8List epubBytes);
}
