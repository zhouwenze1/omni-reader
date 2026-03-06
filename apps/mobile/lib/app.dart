import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/settings/controller/settings_controller.dart';
import 'l10n/l10n.dart';
import 'routes/app_router.dart';
import 'theme/app_theme.dart';

class ReaderMobileApp extends ConsumerWidget {
  const ReaderMobileApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final settingsState = ref.watch(settingsControllerProvider);
    final locale = mobileLocaleFromPreference(settingsState.app.locale);

    return MaterialApp.router(
      onGenerateTitle: (context) => context.l10n.appTitle,
      locale: locale,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('en'),
      ],
      themeMode: MobileAppTheme.modeFromSettings(settingsState.app.themeMode),
      theme: MobileAppTheme.light(),
      darkTheme: MobileAppTheme.dark(),
      routerConfig: router,
    );
  }
}
