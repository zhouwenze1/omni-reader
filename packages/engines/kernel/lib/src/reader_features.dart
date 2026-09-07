import 'package:foundation_domain/domain.dart';

/// Granularity at which a format lets the user select a position/content.
enum ReaderTextSelection {
  /// No selection at all (e.g. pure audio without chapters-to-text, or a scan).
  none,

  /// Text selection (EPUB/TXT/MOBI with a text layer).
  text,

  /// Whole-page selection (comic/PDF scan mode).
  page,

  /// Time-point selection (audiobooks).
  time,
}

/// Annotation kinds a format can store on its own locator semantics.
enum ReaderAnnotationKind {
  /// Anchored text highlight (needs a text layer + quote).
  textHighlight,

  /// Bookmark anchored to a whole page.
  pageBookmark,

  /// Note anchored to a whole page.
  pageNote,

  /// Bookmark anchored to a playback time point.
  timeBookmark,
}

enum ReaderDirection { ltr, rtl }

/// Layout modes a format supports, plus direction/spread defaults.
class ReaderLayoutSupport {
  const ReaderLayoutSupport({
    this.layoutModes = const <String>{},
    this.spreadable = false,
    this.direction = ReaderDirection.ltr,
    this.defaultMode = '',
  });

  /// Subset of [ReaderLayoutMode.supportedValues] this format can render.
  final Set<String> layoutModes;

  /// Whether double-page (paged_spread) reading is available.
  final bool spreadable;

  final ReaderDirection direction;

  /// Layout mode to use when the user setting is absent/`paged_auto`.
  final String defaultMode;

  bool supports(String layoutMode) {
    return layoutModes.contains(ReaderLayoutMode.normalize(layoutMode));
  }
}

/// Fine-grained self-description of what a session can do.
///
/// Complements the coarse [ReaderCapability] set with enough structure for the
/// shared reader chrome to adapt per format (which annotation entries to show,
/// whether selection tools apply, which settings groups make sense, whether a
/// page list / toc panel exists, and how paging/layout behaves).
class ReaderFeatures {
  const ReaderFeatures({
    this.textSelection = ReaderTextSelection.none,
    this.annotationKinds = const <ReaderAnnotationKind>{},
    this.toc = false,
    this.pageList = false,
    this.search = false,
    this.dictionary = false,
    this.translate = false,
    this.readAloud = false,
    this.externalLink = false,
    this.mediaLightbox = false,
    this.layout = const ReaderLayoutSupport(),
    this.autoPageAvailable = false,
    this.keyboardTurnAvailable = false,
    this.volumeTurnAvailable = false,
    this.brightnessSupported = false,
    this.keepScreenOnSupported = false,
  });

  final ReaderTextSelection textSelection;

  /// Annotation kinds the session can persist. Empty means "no annotations".
  final Set<ReaderAnnotationKind> annotationKinds;

  /// Structured TOC (text chapters / audio chapters).
  final bool toc;

  /// Visual page list / thumbnails (comic, PDF pages).
  final bool pageList;

  final bool search;

  /// Selection-tool slots (only meaningful when [textSelection] != none).
  final bool dictionary;
  final bool translate;
  final bool readAloud;

  final bool externalLink;
  final bool mediaLightbox;

  final ReaderLayoutSupport layout;

  /// Timed auto-page-turn (text & comics; false for continuous audio).
  final bool autoPageAvailable;

  /// Desktop keyboard page-turn (arrows/space).
  final bool keyboardTurnAvailable;

  /// Android hardware volume-key page-turn.
  final bool volumeTurnAvailable;

  /// Brightness overlay (any chrome-bearing format).
  final bool brightnessSupported;

  /// Keep screen on while reading (mobile).
  final bool keepScreenOnSupported;

  bool get canAnnotate => annotationKinds.isNotEmpty;

  bool supportsKind(ReaderAnnotationKind kind) =>
      annotationKinds.contains(kind);
}
