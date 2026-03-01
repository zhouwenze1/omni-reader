class ReadingStatsAggregate {
  const ReadingStatsAggregate({
    this.totalReadingMinutes = 0,
    this.totalBooks = 0,
    this.totalCompletedBooks = 0,
    this.totalPagesRead = 0,
    this.totalHighlights = 0,
    this.totalNotes = 0,
    this.totalBookmarks = 0,
    this.consecutiveReadingDays = 0,
    this.maxConsecutiveDays = 0,
    this.lastReadingDay,
  });

  final int totalReadingMinutes;
  final int totalBooks;
  final int totalCompletedBooks;
  final int totalPagesRead;
  final int totalHighlights;
  final int totalNotes;
  final int totalBookmarks;
  final int consecutiveReadingDays;
  final int maxConsecutiveDays;
  final DateTime? lastReadingDay;

  double get totalReadingHours => totalReadingMinutes / 60;

  ReadingStatsAggregate copyWith({
    int? totalReadingMinutes,
    int? totalBooks,
    int? totalCompletedBooks,
    int? totalPagesRead,
    int? totalHighlights,
    int? totalNotes,
    int? totalBookmarks,
    int? consecutiveReadingDays,
    int? maxConsecutiveDays,
    DateTime? lastReadingDay,
  }) {
    return ReadingStatsAggregate(
      totalReadingMinutes: totalReadingMinutes ?? this.totalReadingMinutes,
      totalBooks: totalBooks ?? this.totalBooks,
      totalCompletedBooks: totalCompletedBooks ?? this.totalCompletedBooks,
      totalPagesRead: totalPagesRead ?? this.totalPagesRead,
      totalHighlights: totalHighlights ?? this.totalHighlights,
      totalNotes: totalNotes ?? this.totalNotes,
      totalBookmarks: totalBookmarks ?? this.totalBookmarks,
      consecutiveReadingDays:
          consecutiveReadingDays ?? this.consecutiveReadingDays,
      maxConsecutiveDays: maxConsecutiveDays ?? this.maxConsecutiveDays,
      lastReadingDay: lastReadingDay ?? this.lastReadingDay,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'totalReadingMinutes': totalReadingMinutes,
      'totalBooks': totalBooks,
      'totalCompletedBooks': totalCompletedBooks,
      'totalPagesRead': totalPagesRead,
      'totalHighlights': totalHighlights,
      'totalNotes': totalNotes,
      'totalBookmarks': totalBookmarks,
      'consecutiveReadingDays': consecutiveReadingDays,
      'maxConsecutiveDays': maxConsecutiveDays,
      'lastReadingDay': lastReadingDay?.toIso8601String(),
    };
  }

  factory ReadingStatsAggregate.fromJson(Map<String, Object?> json) {
    return ReadingStatsAggregate(
      totalReadingMinutes: _asInt(json['totalReadingMinutes']) ?? 0,
      totalBooks: _asInt(json['totalBooks']) ?? 0,
      totalCompletedBooks: _asInt(json['totalCompletedBooks']) ?? 0,
      totalPagesRead: _asInt(json['totalPagesRead']) ?? 0,
      totalHighlights: _asInt(json['totalHighlights']) ?? 0,
      totalNotes: _asInt(json['totalNotes']) ?? 0,
      totalBookmarks: _asInt(json['totalBookmarks']) ?? 0,
      consecutiveReadingDays: _asInt(json['consecutiveReadingDays']) ?? 0,
      maxConsecutiveDays: _asInt(json['maxConsecutiveDays']) ?? 0,
      lastReadingDay: _asDateTime(json['lastReadingDay']),
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
