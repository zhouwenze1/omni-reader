/// 单条阅读会话记录(统计同步的传输形态)。
///
/// 跨设备合并键为 (deviceId, startedAtMs):同一设备同一起点即同一段阅读。
class ReadingSessionRecord {
  const ReadingSessionRecord({
    required this.deviceId,
    required this.bookUid,
    required this.startedAtMs,
    required this.endedAtMs,
    required this.seconds,
    required this.day,
    required this.startHour,
  });

  final String deviceId;
  final String bookUid;
  final int startedAtMs;
  final int endedAtMs;
  final int seconds;
  final String day;
  final int startHour;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'deviceId': deviceId,
        'bookUid': bookUid,
        'startedAt': startedAtMs,
        'endedAt': endedAtMs,
        'seconds': seconds,
        'day': day,
        'startHour': startHour,
      };

  factory ReadingSessionRecord.fromJson(Map<String, dynamic> json) {
    return ReadingSessionRecord(
      deviceId: '${json['deviceId'] ?? ''}',
      bookUid: '${json['bookUid'] ?? ''}',
      startedAtMs: (json['startedAt'] as num?)?.toInt() ?? 0,
      endedAtMs: (json['endedAt'] as num?)?.toInt() ?? 0,
      seconds: (json['seconds'] as num?)?.toInt() ?? 0,
      day: '${json['day'] ?? ''}',
      startHour: (json['startHour'] as num?)?.toInt() ?? 0,
    );
  }
}
