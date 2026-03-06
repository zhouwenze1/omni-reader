import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/settings/controller/settings_controller.dart';
import 'routes/app_router.dart';
import 'theme/app_theme.dart';

class ReaderMobileApp extends ConsumerWidget {
  const ReaderMobileApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final settingsState = ref.watch(settingsControllerProvider);

    return MaterialApp.router(
      title: 'Reader Mobile',
      themeMode: MobileAppTheme.modeFromSettings(settingsState.app.themeMode),
      theme: MobileAppTheme.light(),
      darkTheme: MobileAppTheme.dark(),
      routerConfig: router,
    );
  }
}
