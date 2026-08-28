class BookTocItem {
  const BookTocItem({
    required this.id,
    required this.title,
    required this.href,
    required this.order,
    this.level = 0,
    this.parentId,
  });

  final String id;
  final String title;
  final String href;
  final int order;
  final int level;
  final String? parentId;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'title': title,
      'href': href,
      'order': order,
      'level': level,
      'parentId': parentId,
    };
  }
}

