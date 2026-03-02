import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation_domain/domain.dart';
import 'package:window_manager/window_manager.dart';

import 'features/settings/controller/settings_controller.dart';
import 'routes/app_router.dart';
import 'utils/window_util.dart';

class ReaderDesktopApp extends ConsumerStatefulWidget {
  const ReaderDesktopApp({super.key});

  @override
  ConsumerState<ReaderDesktopApp> createState() => _ReaderDesktopAppState();
}

class _ReaderDesktopAppState extends ConsumerState<ReaderDesktopApp>
    with WindowListener {
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowClose() async {
    if (!mounted) {
      return;
    }
    await WindowUtil.requestExit(context);
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final settingsState = ref.watch(settingsControllerProvider);
    final themeMode = _toThemeMode(settingsState.app.themeMode);

    return MaterialApp.router(
      title: 'Reader Desktop',
      themeMode: themeMode,
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}

ThemeMode _toThemeMode(AppThemeMode mode) {
  switch (mode) {
    case AppThemeMode.light:
      return ThemeMode.light;
    case AppThemeMode.dark:
      return ThemeMode.dark;
    case AppThemeMode.system:
      return ThemeMode.system;
  }
}
