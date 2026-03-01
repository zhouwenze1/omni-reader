enum BookFormat { epub, pdf, ldf, audio, comicZip, unknown }

extension BookFormatX on BookFormat {
  String get value {
    switch (this) {
      case BookFormat.epub:
        return 'epub';
      case BookFormat.pdf:
        return 'pdf';
      case BookFormat.ldf:
        return 'ldf';
      case BookFormat.audio:
        return 'audio';
      case BookFormat.comicZip:
        return 'comic_zip';
      case BookFormat.unknown:
        return 'unknown';
    }
  }
}

BookFormat bookFormatFromValue(Object? value) {
  switch (value?.toString().toLowerCase()) {
    case 'epub':
      return BookFormat.epub;
    case 'pdf':
      return BookFormat.pdf;
    case 'ldf':
      return BookFormat.ldf;
    case 'audio':
      return BookFormat.audio;
    case 'comic_zip':
    case 'comiczip':
    case 'zip':
      return BookFormat.comicZip;
    default:
      return BookFormat.unknown;
  }
}

enum BookReadingStatus { unread, reading, finished, abandoned }

extension BookReadingStatusX on BookReadingStatus {
  String get value {
    switch (this) {
      case BookReadingStatus.unread:
        return 'unread';
      case BookReadingStatus.reading:
        return 'reading';
      case BookReadingStatus.finished:
        return 'finished';
      case BookReadingStatus.abandoned:
        return 'abandoned';
    }
  }
}

BookReadingStatus bookReadingStatusFromValue(Object? value) {
  switch (value?.toString().toLowerCase()) {
    case 'reading':
      return BookReadingStatus.reading;
    case 'finished':
      return BookReadingStatus.finished;
    case 'abandoned':
      return BookReadingStatus.abandoned;
    default:
      return BookReadingStatus.unread;
  }
}

class Book {
  const Book({
    required this.id,
    required this.title,
    required this.format,
    required this.filePath,
    required this.createdAt,
    required this.importedAt,
    this.coverPath,
    this.subtitle,
    this.description,
    this.authors = const <String>[],
    this.tags = const <String>[],
    this.category,
    this.language,
    this.publisher,
    this.sizeBytes,
    this.lastOpenedAt,
    this.status = BookReadingStatus.unread,
    this.chapterCount,
    this.audioDurationMs,
  });

  final String id;
  final String title;
  final BookFormat format;
  final String filePath;
  final DateTime createdAt;
  final DateTime importedAt;

  final String? coverPath;
  final String? subtitle;
  final String? description;
  final List<String> authors;
  final List<String> tags;
  final String? category;
  final String? language;
  final String? publisher;
  final int? sizeBytes;
  final DateTime? lastOpenedAt;
  final BookReadingStatus status;
  final int? chapterCount;
  final int? audioDurationMs;

  Duration? get audioDuration =>
      audioDurationMs == null ? null : Duration(milliseconds: audioDurationMs!);

  bool get isAudio => format == BookFormat.audio;

  Book copyWith({
    String? id,
    String? title,
    BookFormat? format,
    String? filePath,
    DateTime? createdAt,
    DateTime? importedAt,
    String? coverPath,
    String? subtitle,
    String? description,
    List<String>? authors,
    List<String>? tags,
    String? category,
    String? language,
    String? publisher,
    int? sizeBytes,
    DateTime? lastOpenedAt,
    BookReadingStatus? status,
    int? chapterCount,
    int? audioDurationMs,
  }) {
    return Book(
      id: id ?? this.id,
      title: title ?? this.title,
      format: format ?? this.format,
      filePath: filePath ?? this.filePath,
      createdAt: createdAt ?? this.createdAt,
      importedAt: importedAt ?? this.importedAt,
      coverPath: coverPath ?? this.coverPath,
      subtitle: subtitle ?? this.subtitle,
      description: description ?? this.description,
      authors: authors ?? this.authors,
      tags: tags ?? this.tags,
      category: category ?? this.category,
      language: language ?? this.language,
      publisher: publisher ?? this.publisher,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      status: status ?? this.status,
      chapterCount: chapterCount ?? this.chapterCount,
      audioDurationMs: audioDurationMs ?? this.audioDurationMs,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'title': title,
      'format': format.value,
      'filePath': filePath,
      'createdAt': createdAt.toIso8601String(),
      'importedAt': importedAt.toIso8601String(),
      'coverPath': coverPath,
      'subtitle': subtitle,
      'description': description,
      'authors': authors,
      'tags': tags,
      'category': category,
      'language': language,
      'publisher': publisher,
      'sizeBytes': sizeBytes,
      'lastOpenedAt': lastOpenedAt?.toIso8601String(),
      'status': status.value,
      'chapterCount': chapterCount,
      'audioDurationMs': audioDurationMs,
    };
  }

  factory Book.fromJson(Map<String, Object?> json) {
    return Book(
      id: _asString(json['id']) ?? '',
      title: _asString(json['title']) ?? '',
      format: bookFormatFromValue(json['format']),
      filePath: _asString(json['filePath']) ?? '',
      createdAt: _asDateTime(json['createdAt']) ?? DateTime.now(),
      importedAt: _asDateTime(json['importedAt']) ?? DateTime.now(),
      coverPath: _asString(json['coverPath']),
      subtitle: _asString(json['subtitle']),
      description: _asString(json['description']),
      authors: _asStringList(json['authors']),
      tags: _asStringList(json['tags']),
      category: _asString(json['category']),
      language: _asString(json['language']),
      publisher: _asString(json['publisher']),
      sizeBytes: _asInt(json['sizeBytes']),
      lastOpenedAt: _asDateTime(json['lastOpenedAt']),
      status: bookReadingStatusFromValue(json['status']),
      chapterCount: _asInt(json['chapterCount']),
      audioDurationMs: _asInt(json['audioDurationMs']),
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

DateTime? _asDateTime(Object? value) {
  if (value is DateTime) {
    return value;
  }
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }
  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  }
  if (value is String) {
    return DateTime.tryParse(value);
  }
  return null;
}

List<String> _asStringList(Object? value) {
  if (value is List<String>) {
    return value;
  }
  if (value is List) {
    return value
        .map((item) => item.toString())
        .where((e) => e.isNotEmpty)
        .toList();
  }
  return const <String>[];
}
