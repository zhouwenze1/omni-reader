class DailyReadingStat {
  const DailyReadingStat({
    required this.date,
    this.readingMinutes = 0,
    this.readPages = 0,
    this.finishedBooks = 0,
  });

  final DateTime date;
  final int readingMinutes;
  final int readPages;
  final int finishedBooks;

  DailyReadingStat copyWith({
    DateTime? date,
    int? readingMinutes,
    int? readPages,
    int? finishedBooks,
  }) {
    return DailyReadingStat(
      date: date ?? this.date,
      readingMinutes: readingMinutes ?? this.readingMinutes,
      readPages: readPages ?? this.readPages,
      finishedBooks: finishedBooks ?? this.finishedBooks,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'date': date.toIso8601String(),
      'readingMinutes': readingMinutes,
      'readPages': readPages,
      'finishedBooks': finishedBooks,
    };
  }

  factory DailyReadingStat.fromJson(Map<String, Object?> json) {
    return DailyReadingStat(
      date: _asDateTime(json['date']) ?? DateTime.now(),
      readingMinutes: _asInt(json['readingMinutes']) ?? 0,
      readPages: _asInt(json['readPages']) ?? 0,
      finishedBooks: _asInt(json['finishedBooks']) ?? 0,
    );
  }
}

class ReadingStatsWeekly {
  const ReadingStatsWeekly({
    required this.weekStart,
    required this.weekEnd,
    this.continuousDays = 0,
    this.readingMinutes = 0,
    this.finishedBooks = 0,
    this.annotationsCount = 0,
    this.daily = const <DailyReadingStat>[],
  });

  final DateTime weekStart;
  final DateTime weekEnd;
  final int continuousDays;
  final int readingMinutes;
  final int finishedBooks;
  final int annotationsCount;
  final List<DailyReadingStat> daily;

  ReadingStatsWeekly copyWith({
    DateTime? weekStart,
    DateTime? weekEnd,
    int? continuousDays,
    int? readingMinutes,
    int? finishedBooks,
    int? annotationsCount,
    List<DailyReadingStat>? daily,
  }) {
    return ReadingStatsWeekly(
      weekStart: weekStart ?? this.weekStart,
      weekEnd: weekEnd ?? this.weekEnd,
      continuousDays: continuousDays ?? this.continuousDays,
      readingMinutes: readingMinutes ?? this.readingMinutes,
      finishedBooks: finishedBooks ?? this.finishedBooks,
      annotationsCount: annotationsCount ?? this.annotationsCount,
      daily: daily ?? this.daily,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'weekStart': weekStart.toIso8601String(),
      'weekEnd': weekEnd.toIso8601String(),
      'continuousDays': continuousDays,
      'readingMinutes': readingMinutes,
      'finishedBooks': finishedBooks,
      'annotationsCount': annotationsCount,
      'daily': daily.map((item) => item.toJson()).toList(),
    };
  }

  factory ReadingStatsWeekly.fromJson(Map<String, Object?> json) {
    return ReadingStatsWeekly(
      weekStart: _asDateTime(json['weekStart']) ?? DateTime.now(),
      weekEnd: _asDateTime(json['weekEnd']) ?? DateTime.now(),
      continuousDays: _asInt(json['continuousDays']) ?? 0,
      readingMinutes: _asInt(json['readingMinutes']) ?? 0,
      finishedBooks: _asInt(json['finishedBooks']) ?? 0,
      annotationsCount: _asInt(json['annotationsCount']) ?? 0,
      daily: _asList(
        json['daily'],
      ).map((item) => DailyReadingStat.fromJson(item)).toList(),
    );
  }
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

List<Map<String, Object?>> _asList(Object? value) {
  if (value is List<Map<String, Object?>>) {
    return value;
  }
  if (value is List) {
    return value
        .whereType<Map>()
        .map(
          (entry) => entry.map((key, item) => MapEntry(key.toString(), item)),
        )
        .toList();
  }
  return const <Map<String, Object?>>[];
}
