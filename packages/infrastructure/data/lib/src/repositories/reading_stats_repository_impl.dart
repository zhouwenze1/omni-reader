import 'dart:math' as math;

import 'package:foundation_domain/domain.dart';

import '../db/reading_stats_dao.dart';

/// [ReadingStatsRepository] 的 sqlite 实现。
///
/// day 桶在写入时由会话起点计算并冗余存储(day/startHour 列),
/// 查询端因此不需要 SQLite 日期函数,避免时区/本地化差异。
class ReadingStatsRepositoryImpl implements ReadingStatsRepository {
  ReadingStatsRepositoryImpl(this._dao);

  static const String deletedBookTitle = '已删除的书籍';

  final ReadingStatsDao _dao;

  @override
  Future<void> recordSession({
    required String bookUid,
    required DateTime startedAt,
    required DateTime endedAt,
  }) async {
    if (endedAt.isBefore(startedAt)) {
      return;
    }
    // 防御时钟跳变:起点明显处于未来的段丢弃。
    if (startedAt.isAfter(DateTime.now().add(const Duration(minutes: 1)))) {
      return;
    }
    final seconds = endedAt.difference(startedAt).inSeconds;
    if (seconds < 1) {
      return;
    }
    await _dao.insertSession(
      bookUid: bookUid,
      startedAtMs: startedAt.millisecondsSinceEpoch,
      endedAtMs: endedAt.millisecondsSinceEpoch,
      seconds: seconds,
      day: formatDay(startedAt),
      startHour: startedAt.hour,
    );
  }

  @override
  Future<int> totalSeconds() => _dao.totalSeconds();

  @override
  Future<int> secondsBetween(DateTime from, DateTime to) {
    return _dao.secondsBetween(
        from.millisecondsSinceEpoch, to.millisecondsSinceEpoch);
  }

  @override
  Future<List<DailyReadingStat>> dailySeconds(DateTime from, DateTime to) {
    return _dao.dailySeconds(
      from.millisecondsSinceEpoch,
      to.millisecondsSinceEpoch,
    );
  }

  @override
  Future<List<MonthlyReadingStat>> monthlySeconds(DateTime from, DateTime to) {
    return _dao.monthlySeconds(
      from.millisecondsSinceEpoch,
      to.millisecondsSinceEpoch,
    );
  }

  @override
  Future<List<HourlyReadingStat>> hourlySeconds(
      DateTime from, DateTime to) async {
    final sparse = await _dao.hourlySeconds(
      from.millisecondsSinceEpoch,
      to.millisecondsSinceEpoch,
    );
    final byHour = <int, int>{for (final it in sparse) it.hour: it.seconds};
    return List<HourlyReadingStat>.generate(
      24,
      (hour) => HourlyReadingStat(hour: hour, seconds: byHour[hour] ?? 0),
    );
  }

  @override
  Future<List<BookReadingStat>> topBooks(
    DateTime from,
    DateTime to, {
    int limit = 5,
  }) {
    return _dao.topBooks(
      from.millisecondsSinceEpoch,
      to.millisecondsSinceEpoch,
      deletedBookTitle,
      limit,
    );
  }

  @override
  Future<StreakInfo> streak() async {
    final days = await _dao.allActiveDays();
    return computeStreak(days, DateTime.now());
  }

  @override
  Future<Set<String>> activeDays(DateTime from, DateTime to) async {
    final days = await _dao.activeDays(
      from.millisecondsSinceEpoch,
      to.millisecondsSinceEpoch,
    );
    return days.toSet();
  }

  /// 连读计算:今天或昨天有阅读则向前逐日数 current;
  /// 排序后的日期串扫一遍取最长连续段。
  static StreakInfo computeStreak(List<String> sortedDays, DateTime now) {
    if (sortedDays.isEmpty) {
      return const StreakInfo(currentDays: 0, longestDays: 0);
    }
    final daySet = sortedDays.toSet();
    var current = 0;
    final today = DateTime(now.year, now.month, now.day);
    final anchor = daySet.contains(formatDay(today))
        ? today
        : daySet.contains(formatDay(today.subtract(const Duration(days: 1))))
            ? today.subtract(const Duration(days: 1))
            : null;
    if (anchor != null) {
      var cursor = anchor;
      while (daySet.contains(formatDay(cursor))) {
        current += 1;
        cursor = cursor.subtract(const Duration(days: 1));
      }
    }

    var longest = 0;
    var run = 0;
    DateTime? previous;
    for (final day in sortedDays) {
      final date = parseDay(day);
      if (previous != null && date.difference(previous).inDays == 1) {
        run += 1;
      } else {
        run = 1;
      }
      longest = math.max(longest, run);
      previous = date;
    }
    return StreakInfo(currentDays: current, longestDays: longest);
  }

  static String formatDay(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year.toString().padLeft(4, '0')}-$month-$day';
  }

  static DateTime parseDay(String day) {
    return DateTime(
      int.parse(day.substring(0, 4)),
      int.parse(day.substring(5, 7)),
      int.parse(day.substring(8, 10)),
    );
  }
}
