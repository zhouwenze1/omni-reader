import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ui/shared_ui.dart';

void main() {
  final now = DateTime(2026, 8, 26, 12); // 周三,本周内还有未来日(周四~周日)

  Widget subject(Map<String, int> secondsByDay) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ReadingHeatmap(
            weeks: 15,
            secondsByDay: secondsByDay,
            now: now,
            monthLabel: (month) => '$month月',
            weekdayLabels: const ['一', '', '三', '', '五', '', ''],
            dayLabel: (day, seconds) => '${statsDayKey(day)}:${seconds}s',
            lessLabel: '少',
            moreLabel: '多',
          ),
        ),
      ),
    );
  }

  testWidgets('renders 15 weeks × 7 rows of cells', (tester) async {
    await tester.pumpWidget(subject({'2026-08-26': 3600}));
    // 全部格子(含未来)都有 hm- key。
    final start = heatmapStart(now, 15);
    final first = find.byKey(ValueKey('hm-${statsDayKey(start)}'));
    expect(first, findsOneWidget);
    final last = find.byKey(ValueKey('hm-${statsDayKey(now)}'));
    expect(last, findsOneWidget);
    // 窗口起点是 15 周前的周一。
    expect(statsDayKey(start), '2026-05-18');
  });

  testWidgets('tap on a past day shows its label; future day is inert',
      (tester) async {
    await tester.pumpWidget(subject({'2026-08-26': 3600}));

    await tester.tap(find.byKey(const ValueKey('hm-2026-08-26')));
    await tester.pump();
    expect(find.textContaining('2026-08-26:3600s'), findsOneWidget);

    // 周四属于未来:不可点,说明文案仍是上次选中的。
    await tester.tap(
      find.byKey(const ValueKey('hm-2026-08-27')),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(find.textContaining('2026-08-27'), findsNothing);
    expect(find.textContaining('2026-08-26:3600s'), findsOneWidget);
  });

  testWidgets('empty map renders all-zero cells without errors',
      (tester) async {
    await tester.pumpWidget(subject(const {}));
    expect(find.text('少'), findsOneWidget);
    expect(find.text('多'), findsOneWidget);
  });
}
