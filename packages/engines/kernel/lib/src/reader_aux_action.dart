/// An auxiliary action the session offers, surfaced by the shared reader UI
/// (e.g. the "more" menu) instead of the page branching on a format string.
class ReaderAuxAction {
  const ReaderAuxAction({
    required this.id,
    required this.iconKey,
    required this.labelKey,
    this.enabled = true,
  });

  /// Stable id the UI routes on (e.g. `pdfOutline`, `pageList`, `chapterPrev`).
  final String id;

  /// Logical icon name; each app maps it to its IconData set.
  final String iconKey;

  /// l10n key the UI resolves to a localized label.
  final String labelKey;

  final bool enabled;

  @override
  bool operator ==(Object other) =>
      other is ReaderAuxAction && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
