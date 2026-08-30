/// 统计中心/周报卡共享的状态与格式化工具(双端通用)。
///
/// 本文件刻意保持纯 Dart、不含 l10n:单位文案由调用方以回调注入。
library;

/// 统计中心趋势类模块的时间窗。
enum StatsRange { week, month, year }

/// 周报卡 v2 的阅读摘要(当前连读天数 + 本自然周累计阅读秒数)。
class WeeklyReadingSummary {
  const WeeklyReadingSummary({
    required this.streakDays,
    required this.weekSeconds,
  });

  final int streakDays;
  final int weekSeconds;
}

/// 本地时区「本周」的起点:周一 00:00(周一为一周之首)。
DateTime weekStartLocal(DateTime now) {
  final midnight = DateTime(now.year, now.month, now.day);
  return midnight.subtract(Duration(days: midnight.weekday - 1));
}

/// 秒数本地化回调:hours/mnn 由格式化器按 60 进制折算后传入,
/// 由 l10n 层决定 "27小时17分钟" / "27h 17m" 等形态。
typedef ReadingDurationLocalizer = String Function(int hours, int minutes);

/// 把阅读秒数折算为 (hours, minutes) 并交给本地化回调;
/// 负数按 0 处理,不足一分钟折算为 0 分钟。
String formatReadingDuration(int seconds, ReadingDurationLocalizer localize) {
  final safe = seconds < 0 ? 0 : seconds;
  final hours = safe ~/ 3600;
  final minutes = (safe % 3600) ~/ 60;
  return localize(hours, minutes);
}
