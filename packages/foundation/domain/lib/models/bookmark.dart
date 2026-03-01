import 'locator.dart';

class Bookmark {
  const Bookmark({
    required this.id,
    required this.bookId,
    required this.locator,
    required this.createdAt,
    this.updatedAt,
    this.title,
    this.note,
  });

  final String id;
  final String bookId;
  final Locator locator;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? title;
  final String? note;

  Bookmark copyWith({
    String? id,
    String? bookId,
    Locator? locator,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? title,
    String? note,
  }) {
    return Bookmark(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      locator: locator ?? this.locator,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      title: title ?? this.title,
      note: note ?? this.note,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'bookId': bookId,
      'locator': locator.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'title': title,
      'note': note,
    };
  }

  factory Bookmark.fromJson(Map<String, Object?> json) {
    return Bookmark(
      id: _asString(json['id']) ?? '',
      bookId: _asString(json['bookId']) ?? '',
      locator: Locator.fromJson(
        _asMap(json['locator']) ?? const <String, Object?>{},
      ),
      createdAt: _asDateTime(json['createdAt']) ?? DateTime.now(),
      updatedAt: _asDateTime(json['updatedAt']),
      title: _asString(json['title']),
      note: _asString(json['note']),
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

Map<String, Object?>? _asMap(Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return null;
}
