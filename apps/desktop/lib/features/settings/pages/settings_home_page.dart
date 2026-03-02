import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../routes/route_paths.dart';

class SettingsHomePage extends StatelessWidget {
  const SettingsHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _entry(context, Icons.settings, 'APP 设置', RoutePaths.appSettings),
          _entry(context, Icons.chrome_reader_mode, '阅读器设置', RoutePaths.readerSettings),
          _entry(context, Icons.cloud_outlined, '云端设置', RoutePaths.cloudSettings),
          _entry(context, Icons.info_outline, '关于软件', RoutePaths.about),
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
}
