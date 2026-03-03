import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation_domain/domain.dart';
import 'package:window_manager/window_manager.dart';

import 'features/settings/controller/settings_controller.dart';
import 'l10n/app_localizations.dart';
import 'routes/app_router.dart';
import 'utils/window_util.dart';

class ReaderDesktopApp extends ConsumerStatefulWidget {
  const ReaderDesktopApp({super.key});

  @override
  ConsumerState<ReaderDesktopApp> createState() => _ReaderDesktopAppState();
}

class _ReaderDesktopAppState extends ConsumerState<ReaderDesktopApp>
    with WindowListener {
  bool _closing = false;

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
    if (!mounted || _closing) {
      return;
    }
    _closing = true;
    try {
      final router = ref.read(appRouterProvider);
      final dialogContext = router.routerDelegate.navigatorKey.currentContext;
      if (dialogContext == null) {
        await WindowUtil.forceExit();
        return;
      }
      await WindowUtil.requestExit(dialogContext);
    } finally {
      _closing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final settingsState = ref.watch(settingsControllerProvider);
    final themeMode = _toThemeMode(settingsState.app.themeMode);
    final locale = _toLocale(settingsState.app.locale);

    return MaterialApp.router(
      onGenerateTitle: (context) => context.l10n.appTitle,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
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
      builder: (context, child) {
        final theme = Theme.of(context);
        final brightness = theme.brightness;
        final colorScheme = theme.colorScheme;
        final content = child ?? const SizedBox.shrink();
        return ColoredBox(
          color: colorScheme.surface,
          child: Column(
            children: [
              SizedBox(
                height: kWindowCaptionHeight,
                child: WindowCaption(
                  brightness: brightness,
                  backgroundColor: colorScheme.surface,
                  title: Text(
                    'Reader Desktop',
                    style: TextStyle(
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
              Expanded(child: content),
            ],
          ),
        );
      },
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

Locale? _toLocale(String locale) {
  final normalized = locale.trim().toLowerCase();
  if (normalized.isEmpty || normalized == 'system') {
    return null;
  }
  if (normalized.startsWith('zh')) {
    return const Locale('zh');
  }
  if (normalized.startsWith('en')) {
    return const Locale('en');
  }
  return null;
}
