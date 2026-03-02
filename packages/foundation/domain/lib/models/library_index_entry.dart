class LibraryIndexEntry {
  const LibraryIndexEntry({
    required this.bookUid,
    required this.fingerprint,
    required this.format,
    required this.title,
    required this.authors,
    this.categoryId,
    this.coverRelPath,
    required this.importedAt,
    required this.updatedAt,
    this.lastOpenedAt,
    this.cachedProgress,
  });

  final String bookUid;
  final String fingerprint;
  final String format;
  final String title;
  final List<String> authors;
  final String? categoryId;
  final String? coverRelPath;
  final DateTime importedAt;
  final DateTime updatedAt;
  final DateTime? lastOpenedAt;
  final double? cachedProgress;

  factory LibraryIndexEntry.fromJson(Map<String, dynamic> json) {
    return LibraryIndexEntry(
      bookUid: json['bookUid'] as String,
      fingerprint: json['fingerprint'] as String,
      format: json['format'] as String,
      title: json['title'] as String,
      authors: (json['authors'] as List<dynamic>? ?? const [])
          .map((it) => '$it')
          .toList(),
      categoryId: json['categoryId'] as String?,
      coverRelPath: json['coverRelPath'] as String?,
      importedAt: DateTime.fromMillisecondsSinceEpoch(
        (json['importedAt'] as num).toInt(),
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (json['updatedAt'] as num).toInt(),
      ),
      lastOpenedAt: json['lastOpenedAt'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              (json['lastOpenedAt'] as num).toInt(),
            ),
      cachedProgress: (json['cachedProgress'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bookUid': bookUid,
      'fingerprint': fingerprint,
      'format': format,
      'title': title,
      'authors': authors,
      'categoryId': categoryId,
      'coverRelPath': coverRelPath,
      'importedAt': importedAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'lastOpenedAt': lastOpenedAt?.millisecondsSinceEpoch,
      'cachedProgress': cachedProgress,
    };
  }
}
