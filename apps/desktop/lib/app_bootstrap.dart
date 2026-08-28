import 'package:engine_epub/engine_epub.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infrastructure_data/data.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'di/providers.dart';

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
