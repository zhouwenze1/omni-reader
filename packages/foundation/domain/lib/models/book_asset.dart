enum BookAssetType {
  originalFile,
  coverImage,
  extractedBundle,
  sidecar,
  audioTrack,
  unknown,
}

extension BookAssetTypeX on BookAssetType {
  String get value {
    switch (this) {
      case BookAssetType.originalFile:
        return 'original_file';
      case BookAssetType.coverImage:
        return 'cover_image';
      case BookAssetType.extractedBundle:
        return 'extracted_bundle';
      case BookAssetType.sidecar:
        return 'sidecar';
      case BookAssetType.audioTrack:
        return 'audio_track';
      case BookAssetType.unknown:
        return 'unknown';
    }
  }
}

BookAssetType bookAssetTypeFromValue(Object? value) {
  switch (value?.toString().toLowerCase()) {
    case 'original_file':
      return BookAssetType.originalFile;
    case 'cover_image':
      return BookAssetType.coverImage;
    case 'extracted_bundle':
      return BookAssetType.extractedBundle;
    case 'sidecar':
      return BookAssetType.sidecar;
    case 'audio_track':
      return BookAssetType.audioTrack;
    default:
      return BookAssetType.unknown;
  }
}

class BookAsset {
  const BookAsset({
    required this.id,
    required this.bookId,
    required this.type,
    required this.path,
    required this.createdAt,
    this.mimeType,
    this.sizeBytes,
    this.updatedAt,
    this.metadata = const <String, Object?>{},
  });

  final String id;
  final String bookId;
  final BookAssetType type;
  final String path;
  final DateTime createdAt;
  final String? mimeType;
  final int? sizeBytes;
  final DateTime? updatedAt;
  final Map<String, Object?> metadata;

  BookAsset copyWith({
    String? id,
    String? bookId,
    BookAssetType? type,
    String? path,
    DateTime? createdAt,
    String? mimeType,
    int? sizeBytes,
    DateTime? updatedAt,
    Map<String, Object?>? metadata,
  }) {
    return BookAsset(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      type: type ?? this.type,
      path: path ?? this.path,
      createdAt: createdAt ?? this.createdAt,
      mimeType: mimeType ?? this.mimeType,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'bookId': bookId,
      'type': type.value,
      'path': path,
      'createdAt': createdAt.toIso8601String(),
      'mimeType': mimeType,
      'sizeBytes': sizeBytes,
      'updatedAt': updatedAt?.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory BookAsset.fromJson(Map<String, Object?> json) {
    return BookAsset(
      id: _asString(json['id']) ?? '',
      bookId: _asString(json['bookId']) ?? '',
      type: bookAssetTypeFromValue(json['type']),
      path: _asString(json['path']) ?? '',
      createdAt: _asDateTime(json['createdAt']) ?? DateTime.now(),
      mimeType: _asString(json['mimeType']),
      sizeBytes: _asInt(json['sizeBytes']),
      updatedAt: _asDateTime(json['updatedAt']),
      metadata: _asMap(json['metadata']) ?? const <String, Object?>{},
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

Map<String, Object?>? _asMap(Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return null;
}
