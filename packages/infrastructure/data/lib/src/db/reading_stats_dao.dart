import 'package:drift/drift.dart';
import 'package:foundation_domain/domain.dart';

import 'app_database.dart';

/// reading_sessions 的 raw-SQL 访问层(风格同 [CollectionDao])。
///
/// 全部区间查询按会话起点 `startedAt` 过滤,语义为 [from, to) 左闭右开。
class ReadingStatsDao {
  ReadingStatsDao(this._db);

  final AppDatabase _db;

  Future<void> insertSession({
    required String bookUid,
    required int startedAtMs,
    required int endedAtMs,
    required int seconds,
    required String day,
    required int startHour,
  }) async {
    await _db.customStatement(
      '''
      INSERT INTO reading_sessions
        (bookUid, startedAt, endedAt, seconds, day, startHour)
      VALUES (?, ?, ?, ?, ?, ?)
      ''',
      [bookUid, startedAtMs, endedAtMs, seconds, day, startHour],
    );
  }

  Future<int> totalSeconds() async {
    final row = await _db
        .customSelect(
          'SELECT COALESCE(SUM(seconds), 0) AS s FROM reading_sessions',
        )
        .getSingle();
    return (row.data['s'] as num).toInt();
  }

  Future<int> secondsBetween(int fromMs, int toMs) async {
    final row = await _db.customSelect(
      '''
      SELECT COALESCE(SUM(seconds), 0) AS s
      FROM reading_sessions
      WHERE startedAt >= ? AND startedAt < ?
      ''',
      variables: [Variable.withInt(fromMs), Variable.withInt(toMs)],
    ).getSingle();
    return (row.data['s'] as num).toInt();
  }

  Future<List<DailyReadingStat>> dailySeconds(int fromMs, int toMs) async {
    final rows = await _db.customSelect(
      '''
      SELECT day, SUM(seconds) AS s
      FROM reading_sessions
      WHERE startedAt >= ? AND startedAt < ?
      GROUP BY day
      ORDER BY day
      ''',
      variables: [Variable.withInt(fromMs), Variable.withInt(toMs)],
    ).get();
    return rows
        .map(
          (row) => DailyReadingStat(
            day: row.data['day'] as String,
            seconds: (row.data['s'] as num).toInt(),
          ),
        )
        .toList();
  }

  Future<List<MonthlyReadingStat>> monthlySeconds(int fromMs, int toMs) async {
    final rows = await _db.customSelect(
      '''
      SELECT substr(day, 1, 7) AS month, SUM(seconds) AS s
      FROM reading_sessions
      WHERE startedAt >= ? AND startedAt < ?
      GROUP BY month
      ORDER BY month
      ''',
      variables: [Variable.withInt(fromMs), Variable.withInt(toMs)],
    ).get();
    return rows
        .map(
          (row) => MonthlyReadingStat(
            month: row.data['month'] as String,
            seconds: (row.data['s'] as num).toInt(),
          ),
        )
        .toList();
  }

  /// 稀疏桶(只含有记录的小时);0-23 全量填充由仓库层完成。
  Future<List<HourlyReadingStat>> hourlySeconds(int fromMs, int toMs) async {
    final rows = await _db.customSelect(
      '''
      SELECT startHour, SUM(seconds) AS s
      FROM reading_sessions
      WHERE startedAt >= ? AND startedAt < ?
      GROUP BY startHour
      ORDER BY startHour
      ''',
      variables: [Variable.withInt(fromMs), Variable.withInt(toMs)],
    ).get();
    return rows
        .map(
          (row) => HourlyReadingStat(
            hour: (row.data['startHour'] as num).toInt(),
            seconds: (row.data['s'] as num).toInt(),
          ),
        )
        .toList();
  }

  Future<List<BookReadingStat>> topBooks(
    int fromMs,
    int toMs,
    String deletedBookTitle,
    int limit,
  ) async {
    final rows = await _db.customSelect(
      '''
      SELECT rs.bookUid AS bookUid,
             COALESCE(li.title, ?) AS title,
             li.coverRelPath AS coverRelPath,
             li.cachedProgress AS cachedProgress,
             SUM(rs.seconds) AS s
      FROM reading_sessions rs
      LEFT JOIN library_index li ON li.bookUid = rs.bookUid
      WHERE rs.startedAt >= ? AND rs.startedAt < ?
      GROUP BY rs.bookUid
      ORDER BY s DESC
      LIMIT ?
      ''',
      variables: [
        Variable.withString(deletedBookTitle),
        Variable.withInt(fromMs),
        Variable.withInt(toMs),
        Variable.withInt(limit),
      ],
    ).get();
    return rows
        .map(
          (row) => BookReadingStat(
            bookUid: row.data['bookUid'] as String,
            title: row.data['title'] as String,
            coverRelPath: row.data['coverRelPath'] as String?,
            cachedProgress: (row.data['cachedProgress'] as num?)?.toDouble(),
            seconds: (row.data['s'] as num).toInt(),
          ),
        )
        .toList();
  }

  /// 窗口内有记录的本地日集合(升序)。
  Future<List<String>> activeDays(int fromMs, int toMs) async {
    final rows = await _db.customSelect(
      '''
      SELECT DISTINCT day
      FROM reading_sessions
      WHERE startedAt >= ? AND startedAt < ?
      ORDER BY day
      ''',
      variables: [Variable.withInt(fromMs), Variable.withInt(toMs)],
    ).get();
    return rows.map((row) => row.data['day'] as String).toList();
  }

  /// 全部有记录的本地日(升序,连读计算用)。
  Future<List<String>> allActiveDays() async {
    final rows = await _db
        .customSelect('SELECT DISTINCT day FROM reading_sessions ORDER BY day')
        .get();
    return rows.map((row) => row.data['day'] as String).toList();
  }
}
