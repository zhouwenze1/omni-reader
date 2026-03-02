import 'locator.dart';

enum AnnotationType { bookmark, highlight, note }

AnnotationType annotationTypeFromString(String value) {
  return AnnotationType.values.firstWhere(
    (it) => it.name == value,
    orElse: () => AnnotationType.note,
  );
}

class Annotation {
  const Annotation({
    required this.id,
    required this.bookUid,
    required this.type,
    required this.locator,
    this.text,
    this.note,
    this.color,
    required this.createdAt,
    required this.updatedAt,
    this.extras,
  });

  final String id;
  final String bookUid;
  final AnnotationType type;
  final Locator locator;
  final String? text;
  final String? note;
  final String? color;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? extras;

  factory Annotation.fromJson(Map<String, dynamic> json) {
    return Annotation(
      id: json['id'] as String,
      bookUid: json['bookUid'] as String,
      type: annotationTypeFromString((json['type'] as String?) ?? 'note'),
      locator: Locator.fromJson(
        (json['locator'] as Map).map((k, v) => MapEntry('$k', v)),
      ),
      text: json['text'] as String?,
      note: json['note'] as String?,
      color: json['color'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (json['createdAt'] as num).toInt(),
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (json['updatedAt'] as num).toInt(),
      ),
      extras: _asMap(json['extras']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bookUid': bookUid,
      'type': type.name,
      'locator': locator.toJson(),
      'text': text,
      'note': note,
      'color': color,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'extras': extras,
    };
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, val) => MapEntry('$key', val));
    }
    return null;
  }
}
