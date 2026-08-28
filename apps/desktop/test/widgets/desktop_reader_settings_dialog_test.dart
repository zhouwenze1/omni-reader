import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation_domain/domain.dart';
import 'package:reader_desktop/features/reader/widgets/desktop_reader_settings_dialog.dart';
import 'package:reader_desktop/l10n/app_localizations.dart';

Widget _buildHarness({required ValueChanged<ReaderSettings> onCommit}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: DesktopReaderSettingsDialog(
        initialSettings: const ReaderSettings(),
        onCommit: onCommit,
      ),
    ),
  );
}

void main() {
  testWidgets('scrolls settings in a short window without overflow', (
    tester,
  ) async {
    final errors = <FlutterErrorDetails>[];
    final previousOnError = FlutterError.onError;
    FlutterError.onError = errors.add;
    addTearDown(() {
      FlutterError.onError = previousOnError;
    });

    await tester.binding.setSurfaceSize(const Size(420, 260));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_buildHarness(onCommit: (_) {}));
    await tester.pumpAndSettle();

    expect(find.byType(ListView), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -160));
    await tester.pump();

    expect(
      errors.where((error) => error.exceptionAsString().contains('overflow')),
      isEmpty,
    );
  });

  testWidgets('commits a slider once after the gesture ends', (tester) async {
    var commitCount = 0;
    await tester.pumpWidget(_buildHarness(onCommit: (_) => commitCount++));
    await tester.pumpAndSettle();

    final slider = find.byType(Slider).first;
    final gesture = await tester.startGesture(tester.getCenter(slider));
    await gesture.moveBy(const Offset(60, 0));
    await tester.pump();

    expect(commitCount, 0);
    await gesture.up();
    await tester.pump();
    expect(commitCount, 1);
  });
}
