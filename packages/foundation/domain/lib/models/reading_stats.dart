/// 阅读统计聚合模型(统计中心/周报卡专用,只读)。
///
/// 全部时间以本地时区自然日/自然小时为桶,秒为粒度;不参与序列化。
class DailyReadingStat {
  const DailyReadingStat({required this.day, required this.seconds});

  /// 本地日,格式 `yyyy-MM-dd`。
  final String day;

  final int seconds;
}

class MonthlyReadingStat {
  const MonthlyReadingStat({required this.month, required this.seconds});

  /// 本地月,格式 `yyyy-MM`。
  final String month;

  final int seconds;
}

class HourlyReadingStat {
  const HourlyReadingStat({required this.hour, required this.seconds});

  /// 0-23,本地小时。
  final int hour;

  final int seconds;
}

class BookReadingStat {
  const BookReadingStat({
    required this.bookUid,
    required this.title,
    this.coverRelPath,
    this.cachedProgress,
    required this.seconds,
  });

  final String bookUid;

  /// 书已从书架删除时为兜底名(“已删除的书籍”)。
  final String title;
  final String? coverRelPath;
  final double? cachedProgress;
  final int seconds;
}

class StreakInfo {
  const StreakInfo({required this.currentDays, required this.longestDays});

  /// 以今天或昨天为锚点向前的连续阅读天数;今天未读且昨天也未读为 0。
  final int currentDays;
  final int longestDays;

  @override
  bool operator ==(Object other) =>
      other is StreakInfo &&
      other.currentDays == currentDays &&
      other.longestDays == longestDays;

  @override
  int get hashCode => Object.hash(currentDays, longestDays);
}
