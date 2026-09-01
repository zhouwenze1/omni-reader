import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation_domain/domain.dart';
import 'package:window_manager/window_manager.dart';

import 'di/providers.dart';
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
    final captionTheme = _toCaptionTheme(settingsState.reader.rendererTheme);
    // 阅读页由 ReaderPage 生命周期置位;非阅读页显示顶部标题栏。
    final inReader = ref.watch(readerActiveProvider);

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
        final content = child ?? const SizedBox.shrink();
        return ColoredBox(
          color: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              // 阅读时隐藏顶部标题栏,沉浸式阅读;退出时平滑滑入,避免画面突跳。
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  return SizeTransition(
                    sizeFactor: animation,
                    axisAlignment: -1,
                    child: FadeTransition(
                      opacity: animation,
                      child: child,
                    ),
                  );
                },
                child: inReader
                    ? const SizedBox.shrink(
                        key: ValueKey('reader-caption-hide'))
                    : SizedBox(
                        key: const ValueKey('reader-caption-show'),
                        height: kWindowCaptionHeight,
                        child: ClipRect(
                          child: WindowCaption(
                            brightness: captionTheme.brightness,
                            backgroundColor: captionTheme.backgroundColor,
                            title: Text(
                              'Reader Desktop',
                              style: TextStyle(
                                color: captionTheme.foregroundColor,
                              ),
                            ),
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

_CaptionTheme _toCaptionTheme(String rendererTheme) {
  final normalized = rendererTheme.trim().toLowerCase();
  switch (normalized) {
    case 'night':
    case 'dark':
    case 'black':
      return const _CaptionTheme(
        brightness: Brightness.dark,
        backgroundColor: Color(0xFF090B0F),
        foregroundColor: Color(0xFFE7EAF0),
      );
    case 'sepia':
    case 'tea':
    case 'brown':
      return const _CaptionTheme(
        brightness: Brightness.light,
        backgroundColor: Color(0xFFEFE3C8),
        foregroundColor: Color(0xFF3B2F24),
      );
    case 'day':
    default:
      return const _CaptionTheme(
        brightness: Brightness.light,
        backgroundColor: Color(0xFFF7F7F7),
        foregroundColor: Color(0xFF111318),
      );
  }
}

class _CaptionTheme {
  const _CaptionTheme({
    required this.brightness,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final Brightness brightness;
  final Color backgroundColor;
  final Color foregroundColor;
}
