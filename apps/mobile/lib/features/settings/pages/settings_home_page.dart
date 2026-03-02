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
          Card(
            child: ListTile(
              title: const Text('APP 设置'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(RoutePaths.appSettings),
            ),
          ),
          Card(
            child: ListTile(
              title: const Text('阅读器设置'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(RoutePaths.readerSettings),
            ),
          ),
          Card(
            child: ListTile(
              title: const Text('云端设置'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(RoutePaths.cloudSettings),
            ),
          ),
          Card(
            child: ListTile(
              title: const Text('关于软件'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(RoutePaths.about),
            ),
          ),
        ],
      ),
    );
  }
}
