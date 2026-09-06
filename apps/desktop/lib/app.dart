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
    // 阅读页由 ReaderPage 生命周期置位;阅读时隐藏右上角窗口按钮区。
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
          child: Stack(
            children: [
              Positioned.fill(child: content),
              // 窗口控制一体化:没有独立标题栏、没有标题文字,右上角仅保留
              // 最小化/最大化/关闭按钮;左侧透明区域用于拖动窗口(各页面顶栏
              // 右上角无操作,不会遮挡)。背景透明融入内容,明暗跟随应用主题
              // (themeMode 默认跟随系统深浅色)。阅读时隐藏(阅读页有自己的顶栏)。
              if (!inReader)
                Positioned(
                  top: 0,
                  right: 0,
                  width: 300,
                  height: kWindowCaptionHeight,
                  child: WindowCaption(
                    brightness: Theme.of(context).brightness,
                    backgroundColor: Colors.transparent,
                    title: const SizedBox.shrink(),
                  ),
                ),
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
