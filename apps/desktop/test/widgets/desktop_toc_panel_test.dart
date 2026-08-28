import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation_domain/domain.dart';


import 'package:reader_desktop/features/reader/widgets/desktop_toc_panel.dart';
import 'package:reader_desktop/l10n/app_localizations.dart';

void main() {
  group('DesktopTocPanel', () {
    // 模拟 provider 数据
    final sampleItems = <TocItem>[
      TocItem(
        id: '1',
        bookUid: 'book1',
        title: 'Chapter 1',
        href: 'chapter1.xhtml',
        order: 1,
        level: 0,
        parentId: null,
      ),
      TocItem(
        id: '2',
        bookUid: 'book1',
        title: '  Section 1.1',
        href: 'chapter1.xhtml#s1',
        order: 2,
        level: 1,
        parentId: '1',
      ),
      TocItem(
        id: '3',
        bookUid: 'book1',
        title: '  Section 1.2',
        href: null,
        order: 3,
        level: 1,
        parentId: '1',
      ),
    ];

    testWidgets('renders TOC items with correct indentation and callbacks',
        (tester) async {
      final selected = <TocItem>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tocPanelItemsProvider('book1').overrideWith((ref) => sampleItems),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: DesktopTocPanel(
                bookUid: 'book1',
                onSelect: (item) => selected.add(item),
                onClose: () {},
              ),
            ),
          ),
        ),
      );

      // 加载完成后应显示三项
      await tester.pump();

      expect(find.text('Chapter 1'), findsOneWidget);
      expect(find.text('  Section 1.1'), findsOneWidget);
      expect(find.text('  Section 1.2'), findsOneWidget);

      // 有点击回调的项可以点击
      await tester.tap(find.text('Chapter 1'));
      expect(selected.length, 1);
      expect(selected.first.id, '1');

      // href 为 null 的项不能点击
      await tester.tap(find.text('  Section 1.2'));
      expect(selected.length, 1);
    });

    testWidgets('shows empty state when no items', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tocPanelItemsProvider('book1').overrideWith((ref) => <TocItem>[]),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: DesktopTocPanel(
                bookUid: 'book1',
                onSelect: (_) {},
                onClose: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('No table of contents'), findsOneWidget);
    });

    testWidgets('close button triggers onClose', (tester) async {
      var closed = false;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tocPanelItemsProvider('book1').overrideWith((ref) => sampleItems),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: DesktopTocPanel(
                bookUid: 'book1',
                onSelect: (_) {},
                onClose: () => closed = true,
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      // 找关闭按钮——MaterialLocalizations.closeButtonTooltip => "关闭"
      await tester.tap(find.byTooltip('Close'));
      expect(closed, isTrue);
    });
  });
}