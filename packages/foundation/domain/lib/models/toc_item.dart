class TocItem {
  const TocItem({
    required this.id,
    required this.title,
    required this.href,
    this.parentId,
    this.level = 0,
    this.order = 0,
    this.anchorUid,
    this.children = const <TocItem>[],
  });

  final String id;
  final String title;
  final String href;
  final String? parentId;
  final int level;
  final int order;
  final String? anchorUid;
  final List<TocItem> children;

  bool get hasChildren => children.isNotEmpty;

  TocItem copyWith({
    String? id,
    String? title,
    String? href,
    String? parentId,
    int? level,
    int? order,
    String? anchorUid,
    List<TocItem>? children,
  }) {
    return TocItem(
      id: id ?? this.id,
      title: title ?? this.title,
      href: href ?? this.href,
      parentId: parentId ?? this.parentId,
      level: level ?? this.level,
      order: order ?? this.order,
      anchorUid: anchorUid ?? this.anchorUid,
      children: children ?? this.children,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'title': title,
      'href': href,
      'parentId': parentId,
      'level': level,
      'order': order,
      'anchorUid': anchorUid,
      'children': children.map((item) => item.toJson()).toList(),
    };
  }

  factory TocItem.fromJson(Map<String, Object?> json) {
    return TocItem(
      id: _asString(json['id']) ?? '',
      title: _asString(json['title']) ?? '',
      href: _asString(json['href']) ?? '',
      parentId: _asString(json['parentId']),
      level: _asInt(json['level']) ?? 0,
      order: _asInt(json['order']) ?? 0,
      anchorUid: _asString(json['anchorUid']),
      children: _asList(
        json['children'],
      ).map((item) => TocItem.fromJson(item)).toList(),
    );
  }
}

String? _asString(Object? value) {
  final text = value?.toString();
  if (text == null || text.isEmpty) {
    return null;
  }
  return text;
}

int? _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '');
}

List<Map<String, Object?>> _asList(Object? value) {
  if (value is List<Map<String, Object?>>) {
    return value;
  }
  if (value is List) {
    return value
        .whereType<Map>()
        .map(
          (entry) => entry.map((key, item) => MapEntry(key.toString(), item)),
        )
        .toList();
  }
  return const <Map<String, Object?>>[];
}
