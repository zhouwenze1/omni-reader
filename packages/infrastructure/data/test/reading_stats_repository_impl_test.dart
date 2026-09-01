import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:foundation_domain/domain.dart';
import 'package:infrastructure_data/src/db/app_database.dart';
import 'package:infrastructure_data/src/db/reading_stats_dao.dart';
import 'package:infrastructure_data/src/repositories/reading_stats_repository_impl.dart';

void main() {
  late Directory tempRoot;
  late AppDatabase db;
  late ReadingStatsRepositoryImpl repo;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('reading_stats_test_');
    db = await AppDatabase.open(
      '${tempRoot.path}${Platform.pathSeparator}test.sqlite',
    );
    repo = ReadingStatsRepositoryImpl(ReadingStatsDao(db));
  });

  tearDown(() async {
    await db.close();
    await tempRoot.delete(recursive: true);
  });

  DateTime dayAt(int daysAgo, [int hour = 10, int minute = 0]) {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    return midnight
        .subtract(Duration(days: daysAgo))
        .add(Duration(hours: hour, minutes: minute));
  }

  /// daysAgo 天前(负数=未来)的本地零点,用作窗口边界。
  DateTime midnightAt(int daysAgo) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: daysAgo));
  }

  Future<void> addLibraryBook(
    String bookUid, {
    String title = 'Real Book',
    String? cover,
    double? progress,
  }) async {
    await db.customStatement(
      '''
      INSERT INTO library_index
        (bookUid, fingerprint, format, title, authorsJson, categoryId,
         coverRelPath, importedAt, updatedAt, lastOpenedAt, cachedProgress)
      VALUES (?, ?, 'epub', ?, '[]', NULL, ?, 1, 1, NULL, ?)
      ''',
      [bookUid, 'fp-$bookUid', title, cover, progress],
    );
  }

  test('empty database returns zeroed aggregates without errors', () async {
    expect(await repo.totalSeconds(), 0);
    expect(await repo.dailySeconds(midnightAt(7), midnightAt(-1)), isEmpty);
    expect(await repo.monthlySeconds(midnightAt(90), midnightAt(-1)), isEmpty);
    expect(await repo.topBooks(midnightAt(7), midnightAt(-1)), isEmpty);
    expect(await repo.activeDays(midnightAt(7), midnightAt(-1)), isEmpty);
    expect(
      await repo.streak(),
      const StreakInfo(currentDays: 0, longestDays: 0),
    );
    final hours = await repo.hourlySeconds(midnightAt(7), midnightAt(-1));
    expect(hours, hasLength(24));
    expect(hours.every((it) => it.seconds == 0), isTrue);
  });

  test('dailySeconds groups by local day and secondsBetween is [from, to)',
      () async {
    await repo.recordSession(
      bookUid: 'b1',
      startedAt: dayAt(2, 9),
      endedAt: dayAt(2, 9).add(const Duration(seconds: 100)),
    );
    await repo.recordSession(
      bookUid: 'b1',
      startedAt: dayAt(1, 21),
      endedAt: dayAt(1, 21).add(const Duration(seconds: 50)),
    );

    final daily = await repo.dailySeconds(midnightAt(2), midnightAt(0));
    expect(daily, hasLength(2));
    expect(daily[0].seconds, 100);
    expect(daily[1].seconds, 50);

    // [from, to) 左闭右开:窗口从 day-1 起,不含 day-2。
    expect(await repo.secondsBetween(midnightAt(1), midnightAt(0)), 50);
    expect(await repo.secondsBetween(midnightAt(2), midnightAt(0)), 150);
  });

  test('hourlySeconds returns full 0-23 buckets', () async {
    await repo.recordSession(
      bookUid: 'b1',
      startedAt: dayAt(1, 21, 30),
      endedAt: dayAt(1, 21, 30).add(const Duration(seconds: 200)),
    );
    await repo.recordSession(
      bookUid: 'b1',
      startedAt: dayAt(1, 7),
      endedAt: dayAt(1, 7).add(const Duration(seconds: 30)),
    );

    final hours = await repo.hourlySeconds(midnightAt(1), midnightAt(0));
    expect(hours, hasLength(24));
    expect(hours.firstWhere((it) => it.hour == 21).seconds, 200);
    expect(hours.firstWhere((it) => it.hour == 7).seconds, 30);
    expect(hours.firstWhere((it) => it.hour == 0).seconds, 0);
  });

  test('monthlySeconds groups by yyyy-MM', () async {
    final now = DateTime.now();
    // 用“今天”和“上个月 1 号”作为两个月的锚点,避免月初运行时
    // 本月固定日(如 5 日)落在未来被 recordSession 的时钟防御丢弃。
    final thisMonth = DateTime(now.year, now.month, now.day, 10);
    final lastMonth = DateTime(now.year, now.month - 1, 1, 10);

    await repo.recordSession(
      bookUid: 'b1',
      startedAt: thisMonth,
      endedAt: thisMonth.add(const Duration(seconds: 60)),
    );
    await repo.recordSession(
      bookUid: 'b1',
      startedAt: lastMonth,
      endedAt: lastMonth.add(const Duration(seconds: 90)),
    );

    final months = await repo.monthlySeconds(
      DateTime(now.year, now.month - 1, 1),
      DateTime(now.year, now.month + 1, 1),
    );
    expect(months, hasLength(2));
    expect(months.last.month,
        ReadingStatsRepositoryImpl.formatDay(thisMonth).substring(0, 7));
    expect(months.last.seconds, 60);
    expect(months.first.seconds, 90);
  });

  test('session crossing midnight is bucketed by its start day/hour', () async {
    final start = dayAt(1, 23, 59);
    await repo.recordSession(
      bookUid: 'b1',
      startedAt: start,
      endedAt: start.add(const Duration(seconds: 90)),
    );

    final daily =
        await repo.dailySeconds(midnightAt(1), midnightAt(-1));
    expect(daily, hasLength(1));
    expect(daily.single.day, ReadingStatsRepositoryImpl.formatDay(start));
    expect(daily.single.seconds, 90);

    final hours =
        await repo.hourlySeconds(midnightAt(1), midnightAt(-1));
    expect(hours.firstWhere((it) => it.hour == 23).seconds, 90);
    expect(hours.firstWhere((it) => it.hour == 0).seconds, 0);
  });

  test('streak counts consecutive days anchored on today or yesterday',
      () async {
    // dayAt(0, 10) 即"今天 10:00",在 UTC 上午运行的 CI 上会落在未来,
    // 被 recordSession 的未来时段防御逻辑丢弃。用当天零点保证任何时区都安全。
    for (final daysAgo in [0, 1, 2]) {
      await repo.recordSession(
        bookUid: 'b1',
        startedAt: dayAt(daysAgo, 0),
        endedAt: dayAt(daysAgo, 0).add(const Duration(seconds: 30)),
      );
    }
    final streak = await repo.streak();
    expect(streak.currentDays, 3);
    expect(streak.longestDays, 3);
  });

  test('computeStreak handles gaps and yesterday-only anchors', () {
    final now = DateTime(2026, 8, 30, 12);
    expect(
      ReadingStatsRepositoryImpl.computeStreak(
        ['2026-08-28', '2026-08-29', '2026-08-30'],
        now,
      ),
      const StreakInfo(currentDays: 3, longestDays: 3),
    );
    expect(
      ReadingStatsRepositoryImpl.computeStreak(['2026-08-29'], now),
      const StreakInfo(currentDays: 1, longestDays: 1),
    );
    expect(
      ReadingStatsRepositoryImpl.computeStreak(
        ['2026-08-20', '2026-08-21'],
        now,
      ),
      const StreakInfo(currentDays: 0, longestDays: 2),
    );
    expect(
      ReadingStatsRepositoryImpl.computeStreak(
        ['2026-08-20', '2026-08-22'],
        now,
      ),
      const StreakInfo(currentDays: 0, longestDays: 1),
    );
  });

  test('topBooks joins library_index and falls back for deleted books',
      () async {
    await addLibraryBook(
      'b1',
      title: 'Real Book',
      cover: 'covers/b1.png',
      progress: 0.5,
    );
    await repo.recordSession(
      bookUid: 'b1',
      startedAt: dayAt(1, 10),
      endedAt: dayAt(1, 10).add(const Duration(seconds: 100)),
    );
    await repo.recordSession(
      bookUid: 'ghost',
      startedAt: dayAt(1, 11),
      endedAt: dayAt(1, 11).add(const Duration(seconds: 40)),
    );

    final tops = await repo.topBooks(midnightAt(1), midnightAt(0));
    expect(tops, hasLength(2));
    expect(tops[0].bookUid, 'b1');
    expect(tops[0].title, 'Real Book');
    expect(tops[0].coverRelPath, 'covers/b1.png');
    expect(tops[0].cachedProgress, 0.5);
    expect(tops[0].seconds, 100);
    expect(tops[1].title, ReadingStatsRepositoryImpl.deletedBookTitle);
    expect(tops[1].coverRelPath, isNull);
    expect(tops[1].cachedProgress, isNull);
  });

  test('recordSession discards zero-second, inverted, and future segments',
      () async {
    await repo.recordSession(
      bookUid: 'b1',
      startedAt: dayAt(1, 10),
      endedAt: dayAt(1, 10),
    );
    await repo.recordSession(
      bookUid: 'b1',
      startedAt: dayAt(1, 11),
      endedAt: dayAt(1, 10),
    );
    await repo.recordSession(
      bookUid: 'b1',
      startedAt: DateTime.now().add(const Duration(minutes: 5)),
      endedAt: DateTime.now().add(const Duration(minutes: 6)),
    );
    expect(await repo.totalSeconds(), 0);
  });
}
