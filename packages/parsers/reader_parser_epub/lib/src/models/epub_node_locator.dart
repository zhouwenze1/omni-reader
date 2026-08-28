class EpubNodeLocator {
  const EpubNodeLocator({
    required this.uid,
    required this.xpath,
    required this.tag,
    required this.textStart,
    required this.textLength,
    required this.preview,
  });

  final String uid;
  final String xpath;
  final String tag;
  final int textStart;
  final int textLength;
  final String preview;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'uid': uid,
      'xpath': xpath,
      'tag': tag,
      'textStart': textStart,
      'textLength': textLength,
      'preview': preview,
    };
  }
}

