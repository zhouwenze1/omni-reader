import 'package:reader_desktop/features/library/widgets/sort_menu.dart';
import 'package:reader_desktop/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation_domain/domain.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('SortMenu closed-state selected text is not gray',
      (tester) async {
    LibrarySortMode mode = LibrarySortMode.importedAt;
    await tester.pumpWidget(
      _wrap(
        SortMenu(
          value: mode,
          onChanged: (next) => mode = next,
        ),
      ),
    );

    // 闭合态:找到当前选中项文本并读其继承样式。
    final context = tester.element(find.byType(SortMenu));
    final l10n = AppLocalizations.of(context);
    final label = l10n.sortByImportedAt;
    final finder = find.text(label);
    expect(finder, findsOneWidget, reason: 'label "$label" should show');
    final textContext = tester.element(finder);
    final style = DefaultTextStyle.of(textContext).style;
    final disabledColor = Theme.of(textContext).disabledColor;
    final effectiveColor = style.color;
    expect(
      effectiveColor,
      isNot(disabledColor),
      reason: 'selected item should not render in disabledColor: '
          '$effectiveColor vs disabled $disabledColor',
    );
    final onSurface = Theme.of(textContext).colorScheme.onSurface;
    expect(
      effectiveColor == null || effectiveColor == onSurface,
      isTrue,
      reason: 'expected default/onSurface text, got $effectiveColor '
          '(onSurface=$onSurface)',
    );
  });

  testWidgets('SortMenu stays readable after picking an item', (tester) async {
    LibrarySortMode mode = LibrarySortMode.recentRead;
    await tester.pumpWidget(
      _wrap(
        SortMenu(
          value: mode,
          onChanged: (next) => mode = next,
        ),
      ),
    );

    // 打开菜单。
    await tester.tap(find.byType(DropdownButton<LibrarySortMode>));
    await tester.pumpAndSettle();

    // 选择"最近导入"(importedAt)。
    final context = tester.element(find.byType(SortMenu));
    final l10n = AppLocalizations.of(context);
    await tester.tap(find.text(l10n.sortByImportedAt).last);
    await tester.pumpAndSettle();

    // 模拟父级把 value 更新为新选值。
    await tester.pumpWidget(
      _wrap(
        SortMenu(
          value: LibrarySortMode.importedAt,
          onChanged: (next) => mode = next,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 闭合态选中项文字颜色应为正常前景色。
    final finder = find.text(l10n.sortByImportedAt);
    expect(finder, findsOneWidget);
    final textContext = tester.element(finder);
    final style = DefaultTextStyle.of(textContext).style;
    final disabledColor = Theme.of(textContext).disabledColor;
    final effectiveColor = style.color;
    expect(
      effectiveColor,
      isNot(disabledColor),
      reason: 'after selecting, text should not be gray: $effectiveColor',
    );
  });
}
