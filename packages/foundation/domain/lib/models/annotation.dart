import 'bookmark.dart';
import 'highlight.dart';
import 'locator.dart';
import 'note.dart';

enum AnnotationType { bookmark, highlight, note }

extension AnnotationTypeX on AnnotationType {
  String get value {
    switch (this) {
      case AnnotationType.bookmark:
        return 'bookmark';
      case AnnotationType.highlight:
        return 'highlight';
      case AnnotationType.note:
        return 'note';
    }
  }
}

AnnotationType annotationTypeFromValue(Object? value) {
  switch (value?.toString().toLowerCase()) {
    case 'highlight':
      return AnnotationType.highlight;
    case 'note':
      return AnnotationType.note;
    default:
      return AnnotationType.bookmark;
  }
}

class Annotation {
  const Annotation({
    required this.id,
    required this.bookId,
    required this.type,
    required this.locator,
    required this.createdAt,
    this.updatedAt,
    this.excerpt,
    this.content,
    this.color,
  });

  final String id;
  final String bookId;
  final AnnotationType type;
  final Locator locator;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? excerpt;
  final String? content;
  final String? color;

  factory Annotation.fromBookmark(Bookmark bookmark) {
    return Annotation(
      id: bookmark.id,
      bookId: bookmark.bookId,
      type: AnnotationType.bookmark,
      locator: bookmark.locator,
      createdAt: bookmark.createdAt,
      updatedAt: bookmark.updatedAt,
      excerpt: bookmark.title,
      content: bookmark.note,
    );
  }

  factory Annotation.fromHighlight(Highlight highlight) {
    return Annotation(
      id: highlight.id,
      bookId: highlight.bookId,
      type: AnnotationType.highlight,
      locator: highlight.locator,
      createdAt: highlight.createdAt,
      updatedAt: highlight.updatedAt,
      excerpt: highlight.text,
      content: highlight.note,
      color: highlight.color,
    );
  }

  factory Annotation.fromNote(Note note) {
    return Annotation(
      id: note.id,
      bookId: note.bookId,
      type: AnnotationType.note,
      locator: note.locator,
      createdAt: note.createdAt,
      updatedAt: note.updatedAt,
      excerpt: note.quote,
      content: note.content,
    );
  }

  Annotation copyWith({
    String? id,
    String? bookId,
    AnnotationType? type,
    Locator? locator,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? excerpt,
    String? content,
    String? color,
  }) {
    return Annotation(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      type: type ?? this.type,
      locator: locator ?? this.locator,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      excerpt: excerpt ?? this.excerpt,
      content: content ?? this.content,
      color: color ?? this.color,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'bookId': bookId,
      'type': type.value,
      'locator': locator.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'excerpt': excerpt,
      'content': content,
      'color': color,
    };
  }

  factory Annotation.fromJson(Map<String, Object?> json) {
    return Annotation(
      id: _asString(json['id']) ?? '',
      bookId: _asString(json['bookId']) ?? '',
      type: annotationTypeFromValue(json['type']),
      locator: Locator.fromJson(
        _asMap(json['locator']) ?? const <String, Object?>{},
      ),
      createdAt: _asDateTime(json['createdAt']) ?? DateTime.now(),
      updatedAt: _asDateTime(json['updatedAt']),
      excerpt: _asString(json['excerpt']),
      content: _asString(json['content']),
      color: _asString(json['color']),
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
