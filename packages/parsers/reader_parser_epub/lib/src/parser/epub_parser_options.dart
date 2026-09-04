class EpubParserOptions {
  /// Kept for source compatibility. EPUB repair now happens before parsing,
  /// and this flag no longer appends spine items to a valid TOC.
  const EpubParserOptions({this.enableSmartTocReconciliation = true});

  @Deprecated('Repair EPUB before parsing with reader_epub_repair.')
  final bool enableSmartTocReconciliation;

  @Deprecated('Repair EPUB before parsing with reader_epub_repair.')
  EpubParserOptions copyWith({bool? enableSmartTocReconciliation}) {
    return EpubParserOptions(
      enableSmartTocReconciliation:
          enableSmartTocReconciliation ?? this.enableSmartTocReconciliation,
    );
  }
}
