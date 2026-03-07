import 'package:path/path.dart' as p;

class BookSpineItem {
  const BookSpineItem({
    required this.id,
    required this.href,
    this.mediaType,
    this.properties = const <String>[],
    this.linear = true,
  });

  final String id;
  final String href;
  final String? mediaType;
  final List<String> properties;
  final bool linear;

  factory BookSpineItem.fromJson(Map<String, dynamic> json) {
    return BookSpineItem(
      id: (json['id'] as String?) ?? '',
      href: (json['href'] as String?) ?? '',
      mediaType: json['mediaType'] as String?,
      properties: (json['properties'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => '$item')
          .toList(),
      linear: (json['linear'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'href': href,
      if (mediaType != null && mediaType!.isNotEmpty) 'mediaType': mediaType,
      if (properties.isNotEmpty) 'properties': properties,
      'linear': linear,
    };
  }

  Map<String, dynamic> toSpineManifestJson() {
    return <String, dynamic>{'id': id, 'href': href};
  }
}

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

  factory BookTocItem.fromJson(Map<String, dynamic> json) {
    return BookTocItem(
      id: (json['id'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      href: (json['href'] as String?) ?? '',
      order: (json['order'] as num?)?.toInt() ?? 0,
      level: (json['level'] as num?)?.toInt() ?? 0,
      parentId: json['parentId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'href': href,
      'order': order,
      'level': level,
      if (parentId != null && parentId!.isNotEmpty) 'parentId': parentId,
    };
  }
}

class BookPackage {
  const BookPackage({
    required this.bookUuid,
    required this.opfPath,
    required this.contentRoot,
    required this.spineItems,
    this.toc = const <BookTocItem>[],
    this.title,
    this.authors = const <String>[],
    this.description,
    this.language,
  });

  final String bookUuid;
  final String opfPath;
  final String contentRoot;
  final List<BookSpineItem> spineItems;
  final List<BookTocItem> toc;
  final String? title;
  final List<String> authors;
  final String? description;
  final String? language;

  String get normalizedContentRoot => _normalizeRelative(contentRoot);

  String? get firstSpineHref {
    if (spineItems.isEmpty) {
      return null;
    }
    final first = spineItems.first.href.trim();
    if (first.isEmpty) {
      return null;
    }
    return _normalizeRelative(first);
  }

  BookPackageMetadata toMetadata({
    Map<String, dynamic>? lastLocator,
    DateTime? updatedAt,
  }) {
    return BookPackageMetadata(
      bookUuid: bookUuid,
      opfPath: _normalizeRelative(opfPath),
      contentRoot: _normalizeRelative(contentRoot),
      spineItems: spineItems
          .map((item) => BookSpineItem(
                id: item.id,
                href: _normalizeRelative(item.href),
                mediaType: item.mediaType,
                properties: item.properties,
                linear: item.linear,
              ))
          .toList(),
      toc: toc
          .map((item) => BookTocItem(
                id: item.id,
                title: item.title,
                href: _normalizeRelative(item.href),
                order: item.order,
                level: item.level,
                parentId: item.parentId,
              ))
          .toList(),
      lastLocator: lastLocator,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  static String _normalizeRelative(String value) {
    final trimmed = value.trim().replaceAll('\\', '/');
    if (trimmed.isEmpty || trimmed == '.') {
      return '';
    }
    final normalized = p.posix.normalize(trimmed);
    if (normalized == '.') {
      return '';
    }
    return normalized.replaceFirst(RegExp(r'^/+'), '');
  }
}

class BookPackageMetadata {
  const BookPackageMetadata({
    required this.bookUuid,
    required this.opfPath,
    required this.contentRoot,
    required this.spineItems,
    required this.toc,
    this.lastLocator,
    required this.updatedAt,
  });

  final String bookUuid;
  final String opfPath;
  final String contentRoot;
  final List<BookSpineItem> spineItems;
  final List<BookTocItem> toc;
  final Map<String, dynamic>? lastLocator;
  final DateTime updatedAt;

  factory BookPackageMetadata.fromJson(Map<String, dynamic> json) {
    return BookPackageMetadata(
      bookUuid: (json['bookUuid'] as String?) ?? '',
      opfPath: (json['opfPath'] as String?) ?? '',
      contentRoot: (json['contentRoot'] as String?) ?? '',
      spineItems: (json['spineItems'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map>()
          .map(
            (item) => BookSpineItem.fromJson(
              item.map((key, value) => MapEntry('$key', value)),
            ),
          )
          .toList(),
      toc: (json['toc'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map>()
          .map(
            (item) => BookTocItem.fromJson(
              item.map((key, value) => MapEntry('$key', value)),
            ),
          )
          .toList(),
      lastLocator: _toStringDynamicMap(json['lastLocator']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (json['updatedAt'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'bookUuid': bookUuid,
      'opfPath': opfPath,
      'contentRoot': contentRoot,
      'spineItems': spineItems.map((item) => item.toJson()).toList(),
      'toc': toc.map((item) => item.toJson()).toList(),
      if (lastLocator != null && lastLocator!.isNotEmpty)
        'lastLocator': lastLocator,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  BookPackageMetadata copyWith({
    String? opfPath,
    String? contentRoot,
    List<BookSpineItem>? spineItems,
    List<BookTocItem>? toc,
    Map<String, dynamic>? lastLocator,
    DateTime? updatedAt,
  }) {
    return BookPackageMetadata(
      bookUuid: bookUuid,
      opfPath: opfPath ?? this.opfPath,
      contentRoot: contentRoot ?? this.contentRoot,
      spineItems: spineItems ?? this.spineItems,
      toc: toc ?? this.toc,
      lastLocator: lastLocator ?? this.lastLocator,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String? get firstSpineHref {
    if (spineItems.isEmpty) {
      return null;
    }
    final href = spineItems.first.href.trim();
    if (href.isEmpty) {
      return null;
    }
    return href;
  }

  static Map<String, dynamic>? _toStringDynamicMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, val) => MapEntry('$key', val));
    }
    return null;
  }
}
