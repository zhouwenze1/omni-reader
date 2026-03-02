import 'locator.dart';

class ReadingProgress {
  const ReadingProgress({
    required this.bookUid,
    required this.locator,
    required this.progression,
    required this.updatedAt,
    this.lastReadAt,
  });

  final String bookUid;
  final Locator locator;
  final double progression;
  final DateTime updatedAt;
  final DateTime? lastReadAt;

  factory ReadingProgress.fromJson(Map<String, dynamic> json) {
    return ReadingProgress(
      bookUid: json['bookUid'] as String,
      locator: Locator.fromJson(
        (json['locator'] as Map).map((k, v) => MapEntry('$k', v)),
      ),
      progression: (json['progression'] as num?)?.toDouble() ?? 0,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (json['updatedAt'] as num).toInt(),
      ),
      lastReadAt: json['lastReadAt'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              (json['lastReadAt'] as num).toInt(),
            ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bookUid': bookUid,
      'locator': locator.toJson(),
      'progression': progression,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'lastReadAt': lastReadAt?.millisecondsSinceEpoch,
    };
  }

  ReadingProgress copyWith({
    Locator? locator,
    double? progression,
    DateTime? updatedAt,
    DateTime? lastReadAt,
  }) {
    return ReadingProgress(
      bookUid: bookUid,
      locator: locator ?? this.locator,
      progression: progression ?? this.progression,
      updatedAt: updatedAt ?? this.updatedAt,
      lastReadAt: lastReadAt ?? this.lastReadAt,
    );
  }
}
