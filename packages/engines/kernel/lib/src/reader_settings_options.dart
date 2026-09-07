/// Which settings groups apply to a format. The reader settings UI folds away
/// groups the current session does not support (e.g. typography for comics).
class ReaderSettingsOptions {
  const ReaderSettingsOptions({
    this.textTypography = false,
    this.theme = false,
    this.pageGap = false,
    this.padding = false,
    this.layoutMode = false,
    this.playback = false,
  });

  /// Font family / size / line height / indent — text-layer formats only.
  final bool textTypography;

  /// Day / night / sepia theme (any format with chrome).
  final bool theme;

  /// Inter-page gap setting.
  final bool pageGap;

  /// Margins / padding setting.
  final bool padding;

  /// Layout-mode selector (paged/scroll/spread).
  final bool layoutMode;

  /// Playback speed etc. — time-based formats only.
  final bool playback;

  static const ReaderSettingsOptions textBook = ReaderSettingsOptions(
    textTypography: true,
    theme: true,
    pageGap: true,
    padding: true,
    layoutMode: true,
  );

  static const ReaderSettingsOptions comic = ReaderSettingsOptions(
    layoutMode: true,
  );

  static const ReaderSettingsOptions audio = ReaderSettingsOptions(
    theme: true,
    playback: true,
  );

  bool get hasAnything =>
      textTypography || theme || pageGap || padding || layoutMode || playback;
}
