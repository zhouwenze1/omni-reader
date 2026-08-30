/// 统计中心/周报卡共享的状态与格式化工具(双端通用)。
///
/// 本文件刻意保持纯 Dart、不含 l10n:单位文案由调用方以回调注入。
library;

import 'package:foundation_domain/domain.dart';

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

/// 本地日键 `yyyy-MM-dd`(与仓储层 reading_sessions.day 约定一致)。
String statsDayKey(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year.toString().padLeft(4, '0')}-$month-$day';
}

/// 本地月键 `yyyy-MM`。
String statsMonthKey(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  return '${value.year.toString().padLeft(4, '0')}-$month';
}

/// 统计中心时间窗:[from, to) 左闭右开;monthly=true 时趋势按月聚合。
class StatsWindow {
  const StatsWindow(this.from, this.to, {this.monthly = false});

  final DateTime from;
  final DateTime to;
  final bool monthly;
}

/// 时间窗语义(spec §4.4):周=本自然周(周一始);月=含今天最近 30 天;
/// 年=含当月最近 12 个自然月。
StatsWindow statsWindowFor(StatsRange range, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  switch (range) {
    case StatsRange.week:
      final from = weekStartLocal(now);
      return StatsWindow(from, from.add(const Duration(days: 7)));
    case StatsRange.month:
      final from = today.subtract(const Duration(days: 29));
      return StatsWindow(from, from.add(const Duration(days: 30)));
    case StatsRange.year:
      return StatsWindow(
        DateTime(now.year, now.month - 11),
        DateTime(now.year, now.month + 1),
        monthly: true,
      );
  }
}

/// 热力图窗口起点:含当前周在内的 [weeks] 周前的周一。
DateTime heatmapStart(DateTime now, int weeks) {
  return weekStartLocal(now).subtract(Duration(days: 7 * (weeks - 1)));
}

/// 柱状图数据点(值为分钟;label 稀疏标注,空串不画标签)。
class StatsBarPoint {
  const StatsBarPoint({
    required this.value,
    this.label = '',
    this.tooltip = '',
    this.highlighted = false,
  });

  final double value;
  final String label;
  final String tooltip;
  final bool highlighted;
}

/// 统计中心一屏数据(窗口相关的桶已按窗口查出)。
class StatsCenterData {
  const StatsCenterData({
    required this.totalSeconds,
    required this.streak,
    required this.finishedBooks,
    required this.totalBooks,
    required this.highlightsCount,
    required this.notesCount,
    required this.bookmarksCount,
    required this.daily,
    required this.monthly,
    required this.hourly,
    required this.topBooks,
    required this.heatDays,
    required this.libraryRootPath,
  });

  final int totalSeconds;
  final StreakInfo streak;
  final int finishedBooks;
  final int totalBooks;
  final int highlightsCount;
  final int notesCount;
  final int bookmarksCount;
  final List<DailyReadingStat> daily;
  final List<MonthlyReadingStat> monthly;
  final List<HourlyReadingStat> hourly;
  final List<BookReadingStat> topBooks;

  /// 热力图窗口(近 15 周)内每天的阅读秒数。
  final Map<String, int> heatDays;

  /// 封面解析根路径(`<libraryRoot>/<bookUid>/<coverRelPath>`)。
  final String libraryRootPath;
}

/// 把稀疏日桶补零展开为从 [from] 起共 [days] 天的秒数数组。
List<int> fillDailySeconds(
    List<DailyReadingStat> daily, DateTime from, int days) {
  final byDay = <String, int>{for (final it in daily) it.day: it.seconds};
  return List<int>.generate(
    days,
    (index) => byDay[statsDayKey(from.add(Duration(days: index)))] ?? 0,
  );
}

/// 把稀疏月桶补零展开为从 [from] 所在月起共 [months] 个月的秒数数组。
List<int> fillMonthlySeconds(
  List<MonthlyReadingStat> monthly,
  DateTime from,
  int months,
) {
  final byMonth = <String, int>{
    for (final it in monthly) it.month: it.seconds,
  };
  return List<int>.generate(
    months,
    (index) {
      final month = DateTime(from.year, from.month + index);
      return byMonth[statsMonthKey(month)] ?? 0;
    },
  );
}
