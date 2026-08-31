import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:foundation_domain/domain.dart';
import 'package:infrastructure_data/data.dart';
import 'package:services_search/services_search.dart';
import 'package:services_sync/services_sync.dart';
import 'package:shared_ui/shared_ui.dart';
import '../features/me/controller/me_controller.dart';

import 'providers.dart';
import 'repositories_providers.dart';

final bookSearchServiceProvider = Provider<BookSearchService>((ref) {
  return BookSearchService(
    booksRootPath: ref.watch(dataModuleProvider).storagePaths.booksRoot.path,
  );
});

/// 阅读进度同步服务。
final syncServiceProvider = Provider<ProgressSyncService>((ref) {
  final dataModule = ref.watch(dataModuleProvider);
  final syncConfigStore = HiveSyncConfigStore(dataModule.settingsBox);
  final syncSource = ProgressSyncSourceImpl(
    progressRepository: dataModule.progressRepository,
    bookRepository: dataModule.bookRepository,
  );
  return ProgressSyncService(
    api: SyncApiClient(),
    source: syncSource,
    configStore: syncConfigStore,
  );
});

/// 周报卡 v2 数据:当前连读天数 + 本自然周累计阅读秒数。
final weeklyReadingSummaryProvider =
    FutureProvider.autoDispose<WeeklyReadingSummary>((ref) async {
  final repository = ref.watch(readingStatsRepositoryProvider);
  final weekStart = weekStartLocal(DateTime.now());
  final streak = await repository.streak();
  final weekSeconds = await repository.secondsBetween(
    weekStart,
    weekStart.add(const Duration(days: 7)),
  );
  return WeeklyReadingSummary(
    streakDays: streak.currentDays,
    weekSeconds: weekSeconds,
  );
});

/// 统计中心一屏数据(窗口相关桶按 [StatsRange] 查询)。
final statsCenterProvider = FutureProvider.autoDispose
    .family<StatsCenterData, StatsRange>((ref, range) async {
  final repository = ref.watch(readingStatsRepositoryProvider);
  final me = ref.watch(meControllerProvider);
  final now = DateTime.now();
  final window = statsWindowFor(range, now);
  final heatFrom = heatmapStart(now, 15);
  final heatTo = weekStartLocal(now).add(const Duration(days: 7));

  final totalSeconds = await repository.totalSeconds();
  final streak = await repository.streak();
  final daily = await repository.dailySeconds(window.from, window.to);
  final monthly = window.monthly
      ? await repository.monthlySeconds(window.from, window.to)
      : const <MonthlyReadingStat>[];
  final hourly = await repository.hourlySeconds(window.from, window.to);
  final topBooks = await repository.topBooks(window.from, window.to);
  final heatDaily = await repository.dailySeconds(heatFrom, heatTo);

  return StatsCenterData(
    totalSeconds: totalSeconds,
    streak: streak,
    finishedBooks: me.completedBooks,
    totalBooks: me.totalBooks,
    highlightsCount: me.highlightsCount,
    notesCount: me.notesCount,
    bookmarksCount: me.bookmarksCount,
    daily: daily,
    monthly: monthly,
    hourly: hourly,
    topBooks: topBooks,
    heatDays: <String, int>{
      for (final item in heatDaily) item.day: item.seconds,
    },
    libraryRootPath: ref.watch(dataModuleProvider).storagePaths.libraryRoot.path,
  );
});
