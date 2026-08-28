import 'package:engine_epub/engine_epub.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infrastructure_data/data.dart';

import 'app.dart';
import 'di/providers.dart';

Future<void> bootstrapMobileApp() async {
  WidgetsFlutterBinding.ensureInitialized();
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
      child: const ReaderMobileApp(),
    ),
  );
}
