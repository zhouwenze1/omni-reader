class TocItem {
  const TocItem({
    required this.id,
    required this.bookUid,
    required this.title,
    this.href,
    required this.order,
    required this.level,
    this.parentId,
  });

  final String id;
  final String bookUid;
  final String title;
  final String? href;
  final int order;
  final int level;
  final String? parentId;

  factory TocItem.fromJson(Map<String, dynamic> json) {
    return TocItem(
      id: json['id'] as String,
      bookUid: json['bookUid'] as String,
      title: json['title'] as String,
      href: json['href'] as String?,
      order: (json['order'] as num?)?.toInt() ?? 0,
      level: (json['level'] as num?)?.toInt() ?? 0,
      parentId: json['parentId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bookUid': bookUid,
      'title': title,
      'href': href,
      'order': order,
      'level': level,
      'parentId': parentId,
    };
  }
}
