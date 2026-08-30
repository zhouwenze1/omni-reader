import '../../models/reading_stats.dart';

/// 阅读时长与会话聚合的存储端口。
///
/// 区间语义统一为 [from, to) 左闭右开,按会话起点(`startedAt`)归桶;
/// 所有桶均为本地时区自然日/自然小时,秒为粒度。
abstract class ReadingStatsRepository {
  /// 记录一段阅读。实现会丢弃:秒数 <1、时间倒挂、起点明显处于未来的段。
  Future<void> recordSession({
    required String bookUid,
    required DateTime startedAt,
    required DateTime endedAt,
  });

  /// 全部累计阅读秒数。
  Future<int> totalSeconds();

  /// 窗口 [from, to) 内的阅读秒数。
  Future<int> secondsBetween(DateTime from, DateTime to);

  /// 窗口内按本地日聚合;只返回有记录的日,无数据的日不出现。
  Future<List<DailyReadingStat>> dailySeconds(DateTime from, DateTime to);

  /// 窗口内按本地月(`yyyy-MM`)聚合;只返回有记录的月。
  Future<List<MonthlyReadingStat>> monthlySeconds(DateTime from, DateTime to);

  /// 窗口内按本地小时聚合;固定返回 0-23 全量桶,无数据的小时为 0。
  Future<List<HourlyReadingStat>> hourlySeconds(DateTime from, DateTime to);

  /// 窗口内按书聚合的时长降序 Top N;书已删除时 title 为兜底名,
  /// cover/progress 为 null。
  Future<List<BookReadingStat>> topBooks(
    DateTime from,
    DateTime to, {
    int limit = 5,
  });

  /// 连读信息(当前连续天数 + 历史最长连续天数)。
  Future<StreakInfo> streak();

  /// 窗口内有阅读记录的本地日集合(`yyyy-MM-dd`),热力图用。
  Future<Set<String>> activeDays(DateTime from, DateTime to);
}
