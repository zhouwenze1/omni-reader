import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ui/shared_ui.dart';

void main() {
  testWidgets('renders four metrics and fires tap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WeeklyReportCardV2(
            streakDays: 7,
            weekSeconds: 27 * 3600 + 17 * 60,
            completedBooks: 3,
            notesHighlightsCount: 47,
            labels: const WeeklyReportLabels(
              coreDataTitle: '核心数据',
              streakPrefix: '坚持',
              streakSuffix: '天连续阅读',
              totalTimePrefix: '共阅读',
              secondaryDataTitle: '次要数据',
              finishedBooksLabel: '已完成书籍数',
              notesHighlightsLabel: '笔记 / 高亮数',
            ),
            formatDuration: (seconds) => formatReadingDuration(
              seconds,
              (hours, minutes) =>
                  hours > 0 ? '$hours小时$minutes分钟' : '$minutes分钟',
            ),
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('核心数据'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('27小时17分钟'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('47'), findsOneWidget);

    await tester.tap(find.byType(WeeklyReportCardV2));
    expect(tapped, isTrue);
  });

  testWidgets('zero data renders zeros without errors', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WeeklyReportCardV2(
            streakDays: 0,
            weekSeconds: 0,
            completedBooks: 0,
            notesHighlightsCount: 0,
            labels: const WeeklyReportLabels(
              coreDataTitle: '核心数据',
              streakPrefix: '坚持',
              streakSuffix: '天连续阅读',
              totalTimePrefix: '共阅读',
              secondaryDataTitle: '次要数据',
              finishedBooksLabel: '已完成书籍数',
              notesHighlightsLabel: '笔记 / 高亮数',
            ),
            formatDuration: (seconds) => formatReadingDuration(
                seconds, (hours, minutes) => '$minutes分钟'),
          ),
        ),
      ),
    );

    expect(find.text('0'), findsNWidgets(3));
  });

  test('formatReadingDuration floors to hours/minutes', () {
    String render(int seconds) => formatReadingDuration(
          seconds,
          (hours, minutes) =>
              hours > 0 ? '${hours}h${minutes}m' : '${minutes}m',
        );
    expect(render(27 * 3600 + 17 * 60), '27h17m');
    expect(render(59), '0m');
    expect(render(-5), '0m');
    expect(render(3600), '1h0m');
  });
}
