class EpubParserOptions {
  const EpubParserOptions({this.enableSmartTocReconciliation = true});

  final bool enableSmartTocReconciliation;

  EpubParserOptions copyWith({bool? enableSmartTocReconciliation}) {
    return EpubParserOptions(
      enableSmartTocReconciliation:
          enableSmartTocReconciliation ?? this.enableSmartTocReconciliation,
    );
  }
}
