import 'package:engine_epub/engine_epub.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infrastructure_data/data.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'di/providers.dart';
import 'utils/window_chrome.dart';

Future<void> bootstrapDesktopApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  const windowOptions = WindowOptions(
    title: 'Reader Desktop',
    minimumSize: Size(1024, 700),
    center: true,
    titleBarStyle: TitleBarStyle.hidden,
    windowButtonVisibility: false,
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setPreventClose(true);
    // 彻底移除 Windows 原生标题栏(WS_CAPTION 等),窗口永久无边框,
    // 由 Flutter 自绘的 WindowCaption 承担标题栏(含拖动+窗口按钮)。
    // 阅读时 WindowCaption 平滑滑入/滑出,避免退出阅读时原生标题栏瞬跳。
    await WindowChrome.setImmersive(true);
    await windowManager.show();
    await windowManager.focus();
  });

  final storagePaths = await StoragePaths.initialize();
  final bookStorageService = BookStorageService(
    booksRootPath: storagePaths.booksRoot.path,
  );
  final dataModule = await DataModule.bootstrap(
    storagePaths: storagePaths,
    epubImportPort: EpubBookImportAdapter(
      EpubImportService(storageService: bookStorageService),
    ),
    bookStoragePort: bookStorageService,
  );

  runApp(
    ProviderScope(
      overrides: [
        dataModuleProvider.overrideWithValue(dataModule),
      ],
      child: const ReaderDesktopApp(),
    ),
  );
}
