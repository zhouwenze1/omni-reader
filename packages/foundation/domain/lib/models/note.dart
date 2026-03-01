import 'locator.dart';

class Note {
  const Note({
    required this.id,
    required this.bookId,
    required this.locator,
    required this.content,
    required this.createdAt,
    this.updatedAt,
    this.quote,
    this.title,
  });

  final String id;
  final String bookId;
  final Locator locator;
  final String content;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? quote;
  final String? title;

  Note copyWith({
    String? id,
    String? bookId,
    Locator? locator,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? quote,
    String? title,
  }) {
    return Note(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      locator: locator ?? this.locator,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      quote: quote ?? this.quote,
      title: title ?? this.title,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'bookId': bookId,
      'locator': locator.toJson(),
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'quote': quote,
      'title': title,
    };
  }

  factory Note.fromJson(Map<String, Object?> json) {
    return Note(
      id: _asString(json['id']) ?? '',
      bookId: _asString(json['bookId']) ?? '',
      locator: Locator.fromJson(
        _asMap(json['locator']) ?? const <String, Object?>{},
      ),
      content: _asString(json['content']) ?? '',
      createdAt: _asDateTime(json['createdAt']) ?? DateTime.now(),
      updatedAt: _asDateTime(json['updatedAt']),
      quote: _asString(json['quote']),
      title: _asString(json['title']),
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
