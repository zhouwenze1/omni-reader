import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infrastructure_data/data.dart';

import 'app.dart';
import 'di/providers.dart';

Future<void> bootstrapDesktopApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dataModule = await DataModule.bootstrap();

  runApp(
    ProviderScope(
      overrides: [
        dataModuleProvider.overrideWithValue(dataModule),
      ],
      child: const ReaderDesktopApp(),
    ),
  );
}
