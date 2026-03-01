import 'locator.dart';

class Highlight {
  const Highlight({
    required this.id,
    required this.bookId,
    required this.locator,
    required this.createdAt,
    this.updatedAt,
    this.text,
    this.color = '#F8E58C',
    this.note,
  });

  final String id;
  final String bookId;
  final Locator locator;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? text;
  final String color;
  final String? note;

  Highlight copyWith({
    String? id,
    String? bookId,
    Locator? locator,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? text,
    String? color,
    String? note,
  }) {
    return Highlight(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      locator: locator ?? this.locator,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      text: text ?? this.text,
      color: color ?? this.color,
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
      'text': text,
      'color': color,
      'note': note,
    };
  }

  factory Highlight.fromJson(Map<String, Object?> json) {
    return Highlight(
      id: _asString(json['id']) ?? '',
      bookId: _asString(json['bookId']) ?? '',
      locator: Locator.fromJson(
        _asMap(json['locator']) ?? const <String, Object?>{},
      ),
      createdAt: _asDateTime(json['createdAt']) ?? DateTime.now(),
      updatedAt: _asDateTime(json['updatedAt']),
      text: _asString(json['text']),
      color: _asString(json['color']) ?? '#F8E58C',
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
