import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../di/services_providers.dart';
import 'package:shared_ui/shared_ui.dart';

class SettingsHomePage extends ConsumerWidget {
  const SettingsHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _entry(context, Icons.settings, l10n.appSettings,
              RoutePaths.appSettings),
          _entry(
            context,
            Icons.chrome_reader_mode,
            l10n.readerSettings,
            RoutePaths.readerSettings,
          ),
          _entry(
            context,
            Icons.cloud_outlined,
            l10n.cloudSettings,
            RoutePaths.cloudSettings,
          ),
          _entrySync(context, ref),
          _entry(context, Icons.info_outline, l10n.about, RoutePaths.about),
        ],
      ),
    );
  }

  Widget _entry(BuildContext context, IconData icon, String title, String path) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push(path),
      ),
    );
  }

  Widget _entrySync(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.sync),
        title: const Text('阅读同步'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  SyncSettingsPage(service: ref.read(syncServiceProvider)),
            ),
          );
        },
      ),
    );
  }
}
