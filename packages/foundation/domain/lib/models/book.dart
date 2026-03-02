enum BookStatus { importing, ready, failed }

BookStatus bookStatusFromString(String value) {
  return BookStatus.values.firstWhere(
    (it) => it.name == value,
    orElse: () => BookStatus.ready,
  );
}

class Book {
  const Book({
    required this.uid,
    required this.format,
    required this.title,
    required this.authors,
    this.description,
    this.language,
    required this.rootDir,
    this.originalRelPath,
    this.coverRelPath,
    required this.tags,
    this.categoryId,
    required this.status,
    required this.importedAt,
    required this.updatedAt,
    this.lastOpenedAt,
    this.sizeBytes,
    this.fileHash,
  });

  final String uid;
  final String format;
  final String title;
  final List<String> authors;
  final String? description;
  final String? language;
  final String rootDir;
  final String? originalRelPath;
  final String? coverRelPath;
  final List<String> tags;
  final String? categoryId;
  final BookStatus status;
  final DateTime importedAt;
  final DateTime updatedAt;
  final DateTime? lastOpenedAt;
  final int? sizeBytes;
  final String? fileHash;

  Book copyWith({
    String? uid,
    String? format,
    String? title,
    List<String>? authors,
    String? description,
    String? language,
    String? rootDir,
    String? originalRelPath,
    String? coverRelPath,
    List<String>? tags,
    String? categoryId,
    BookStatus? status,
    DateTime? importedAt,
    DateTime? updatedAt,
    DateTime? lastOpenedAt,
    int? sizeBytes,
    String? fileHash,
  }) {
    return Book(
      uid: uid ?? this.uid,
      format: format ?? this.format,
      title: title ?? this.title,
      authors: authors ?? this.authors,
      description: description ?? this.description,
      language: language ?? this.language,
      rootDir: rootDir ?? this.rootDir,
      originalRelPath: originalRelPath ?? this.originalRelPath,
      coverRelPath: coverRelPath ?? this.coverRelPath,
      tags: tags ?? this.tags,
      categoryId: categoryId ?? this.categoryId,
      status: status ?? this.status,
      importedAt: importedAt ?? this.importedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      fileHash: fileHash ?? this.fileHash,
    );
  }

  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      uid: json['uid'] as String,
      format: json['format'] as String,
      title: json['title'] as String,
      authors: (json['authors'] as List<dynamic>? ?? const [])
          .map((it) => it.toString())
          .toList(),
      description: json['description'] as String?,
      language: json['language'] as String?,
      rootDir: json['rootDir'] as String,
      originalRelPath: json['originalRelPath'] as String?,
      coverRelPath: json['coverRelPath'] as String?,
      tags: (json['tags'] as List<dynamic>? ?? const [])
          .map((it) => it.toString())
          .toList(),
      categoryId: json['categoryId'] as String?,
      status: bookStatusFromString((json['status'] as String?) ?? 'ready'),
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
      sizeBytes: (json['sizeBytes'] as num?)?.toInt(),
      fileHash: json['fileHash'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'format': format,
      'title': title,
      'authors': authors,
      'description': description,
      'language': language,
      'rootDir': rootDir,
      'originalRelPath': originalRelPath,
      'coverRelPath': coverRelPath,
      'tags': tags,
      'categoryId': categoryId,
      'status': status.name,
      'importedAt': importedAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'lastOpenedAt': lastOpenedAt?.millisecondsSinceEpoch,
      'sizeBytes': sizeBytes,
      'fileHash': fileHash,
    };
  }
}
