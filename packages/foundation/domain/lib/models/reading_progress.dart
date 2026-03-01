import 'locator.dart';

enum ReadingProgressState { notStarted, reading, paused, finished }

extension ReadingProgressStateX on ReadingProgressState {
  String get value {
    switch (this) {
      case ReadingProgressState.notStarted:
        return 'not_started';
      case ReadingProgressState.reading:
        return 'reading';
      case ReadingProgressState.paused:
        return 'paused';
      case ReadingProgressState.finished:
        return 'finished';
    }
  }
}

ReadingProgressState readingProgressStateFromValue(Object? value) {
  switch (value?.toString().toLowerCase()) {
    case 'reading':
      return ReadingProgressState.reading;
    case 'paused':
      return ReadingProgressState.paused;
    case 'finished':
      return ReadingProgressState.finished;
    default:
      return ReadingProgressState.notStarted;
  }
}

class ReadingProgress {
  const ReadingProgress({
    required this.bookId,
    required this.updatedAt,
    this.locator,
    this.progression = 0,
    this.state = ReadingProgressState.notStarted,
    this.chapterIndex,
    this.chapterTitle,
    this.pageIndex,
    this.pageCount,
    this.audioPositionMs,
    this.audioDurationMs,
    this.totalReadingSeconds = 0,
    this.startedAt,
    this.finishedAt,
  });

  final String bookId;
  final Locator? locator;
  final double progression;
  final ReadingProgressState state;
  final int? chapterIndex;
  final String? chapterTitle;
  final int? pageIndex;
  final int? pageCount;
  final int? audioPositionMs;
  final int? audioDurationMs;
  final int totalReadingSeconds;
  final DateTime updatedAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;

  Duration? get audioPosition =>
      audioPositionMs == null ? null : Duration(milliseconds: audioPositionMs!);

  Duration? get audioDuration =>
      audioDurationMs == null ? null : Duration(milliseconds: audioDurationMs!);

  Duration get totalReadingDuration => Duration(seconds: totalReadingSeconds);

  ReadingProgress copyWith({
    String? bookId,
    Locator? locator,
    double? progression,
    ReadingProgressState? state,
    int? chapterIndex,
    String? chapterTitle,
    int? pageIndex,
    int? pageCount,
    int? audioPositionMs,
    int? audioDurationMs,
    int? totalReadingSeconds,
    DateTime? updatedAt,
    DateTime? startedAt,
    DateTime? finishedAt,
  }) {
    return ReadingProgress(
      bookId: bookId ?? this.bookId,
      locator: locator ?? this.locator,
      progression: progression ?? this.progression,
      state: state ?? this.state,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      chapterTitle: chapterTitle ?? this.chapterTitle,
      pageIndex: pageIndex ?? this.pageIndex,
      pageCount: pageCount ?? this.pageCount,
      audioPositionMs: audioPositionMs ?? this.audioPositionMs,
      audioDurationMs: audioDurationMs ?? this.audioDurationMs,
      totalReadingSeconds: totalReadingSeconds ?? this.totalReadingSeconds,
      updatedAt: updatedAt ?? this.updatedAt,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'bookId': bookId,
      'locator': locator?.toJson(),
      'progression': progression,
      'state': state.value,
      'chapterIndex': chapterIndex,
      'chapterTitle': chapterTitle,
      'pageIndex': pageIndex,
      'pageCount': pageCount,
      'audioPositionMs': audioPositionMs,
      'audioDurationMs': audioDurationMs,
      'totalReadingSeconds': totalReadingSeconds,
      'updatedAt': updatedAt.toIso8601String(),
      'startedAt': startedAt?.toIso8601String(),
      'finishedAt': finishedAt?.toIso8601String(),
    };
  }

  factory ReadingProgress.fromJson(Map<String, Object?> json) {
    return ReadingProgress(
      bookId: _asString(json['bookId']) ?? '',
      locator: _asMap(json['locator']) == null
          ? null
          : Locator.fromJson(_asMap(json['locator'])!),
      progression: _asDouble(json['progression']) ?? 0,
      state: readingProgressStateFromValue(json['state']),
      chapterIndex: _asInt(json['chapterIndex']),
      chapterTitle: _asString(json['chapterTitle']),
      pageIndex: _asInt(json['pageIndex']),
      pageCount: _asInt(json['pageCount']),
      audioPositionMs: _asInt(json['audioPositionMs']),
      audioDurationMs: _asInt(json['audioDurationMs']),
      totalReadingSeconds: _asInt(json['totalReadingSeconds']) ?? 0,
      updatedAt: _asDateTime(json['updatedAt']) ?? DateTime.now(),
      startedAt: _asDateTime(json['startedAt']),
      finishedAt: _asDateTime(json['finishedAt']),
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

double? _asDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '');
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
