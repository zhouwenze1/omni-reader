import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:services_search/services_search.dart';
import 'package:shared_ui/shared_ui.dart';

import 'providers.dart';
import 'repositories_providers.dart';

final bookSearchServiceProvider = Provider<BookSearchService>((ref) {
  return BookSearchService(
    booksRootPath: ref.watch(dataModuleProvider).storagePaths.booksRoot.path,
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
