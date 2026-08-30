import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation_domain/domain.dart';
import 'package:reader_mobile/di/services_providers.dart';
import 'package:reader_mobile/features/stats/pages/stats_center_page.dart';
import 'package:shared_ui/shared_ui.dart';

StatsCenterData _fixture({required int totalSeconds}) {
  final today = DateTime.now();
  final todayKey = statsDayKey(today);
  return StatsCenterData(
    totalSeconds: totalSeconds,
    streak: const StreakInfo(currentDays: 3, longestDays: 5),
    finishedBooks: 2,
    totalBooks: 10,
    highlightsCount: 30,
    notesCount: 17,
    bookmarksCount: 5,
    daily: [DailyReadingStat(day: todayKey, seconds: totalSeconds)],
    monthly: const [],
    hourly: [
      for (var hour = 0; hour < 24; hour++)
        HourlyReadingStat(hour: hour, seconds: hour == 21 ? totalSeconds : 0),
    ],
    topBooks: totalSeconds == 0
        ? const []
        : [
            const BookReadingStat(
              bookUid: 'b1',
              title: 'Test Book',
              cachedProgress: 0.4,
              seconds: 3661,
            ),
          ],
    heatDays: {todayKey: totalSeconds},
    libraryRootPath: '',
  );
}

void main() {
  Future<void> pump(WidgetTester tester, StatsCenterData data) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          statsCenterProvider.overrideWith((ref, range) => Future.value(data)),
        ],
        child: const MaterialApp(home: StatsCenterPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders overview, trend, hourly peak and top book',
      (tester) async {
    await pump(tester, _fixture(totalSeconds: 3661));

    // 测试环境无 delegates,l10n 解析为默认英文。首屏断言:
    expect(find.text('1h 1m'), findsOneWidget); // 累计阅读磁贴
    expect(find.textContaining('min/day'), findsOneWidget);
    expect(find.text('Streak'), findsOneWidget);
    expect(find.textContaining('Longest 5 d'), findsOneWidget);

    // SliverList 惰性构建:滚动到下方区块再断言。
    await tester.dragUntilVisible(
      find.text('Peak at 21h'),
      find.byType(ListView),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    expect(find.text('Peak at 21h'), findsOneWidget);

    await tester.dragUntilVisible(
      find.text('Test Book'),
      find.byType(ListView),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    expect(find.text('Test Book'), findsOneWidget);
    // SliverList 会回收首屏外磁贴,Top 书行的时长文案此刻单独在树里。
    expect(find.text('1h 1m'), findsOneWidget);
  });

  testWidgets('zero total shows empty view', (tester) async {
    await pump(tester, _fixture(totalSeconds: 0));
    expect(find.text('Your journey starts here'), findsOneWidget);
  });
}
