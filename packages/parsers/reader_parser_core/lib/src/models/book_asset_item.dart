class BookAssetItem {
  const BookAssetItem({
    required this.id,
    required this.href,
    required this.mediaType,
    this.properties = const <String>[],
    this.linear = true,
    this.title,
  });

  final String id;
  final String href;
  final String mediaType;
  final List<String> properties;
  final bool linear;
  final String? title;

  bool get isHtmlLike =>
      mediaType == 'application/xhtml+xml' || mediaType == 'text/html';

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'href': href,
      'mediaType': mediaType,
      'properties': properties,
      'linear': linear,
      'title': title,
    };
  }
}
