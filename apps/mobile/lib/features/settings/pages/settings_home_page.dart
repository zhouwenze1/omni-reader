import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shared_ui/shared_ui.dart';
import 'backup_import_page.dart';
import 'cache_manage_page.dart';
import 'cloud_options_page.dart';
import 'reading_assist_settings_page.dart';

class SettingsHomePage extends ConsumerWidget {
  const SettingsHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _entry(
            context,
            icon: Icons.settings_outlined,
            title: '应用设置',
            onTap: () => context.push(RoutePaths.appSettings),
          ),
          _entry(
            context,
            icon: Icons.chrome_reader_mode_outlined,
            title: '阅读器设置',
            onTap: () => context.push(RoutePaths.readerSettings),
          ),
          _entry(
            context,
            icon: Icons.auto_awesome_outlined,
            title: '阅读辅助',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ReadingAssistSettingsPage(),
                ),
              );
            },
          ),
          _entry(
            context,
            icon: Icons.cloud_outlined,
            title: '云端设置',
            onTap: () => context.push(RoutePaths.cloudSettings),
          ),
          _entry(
            context,
            icon: Icons.cloud_sync_outlined,
            title: '云端选项',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const CloudOptionsPage(),
                ),
              );
            },
          ),
          _entry(
            context,
            icon: Icons.cleaning_services_outlined,
            title: '缓存管理',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const CacheManagePage(),
                ),
              );
            },
          ),
          _entry(
            context,
            icon: Icons.backup_outlined,
            title: '备份与导入',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const BackupImportPage(),
                ),
              );
            },
          ),
          _entry(
            context,
            icon: Icons.info_outline,
            title: '关于软件',
            onTap: () => context.push(RoutePaths.about),
          ),
        ],
      ),
    );
  }

  Widget _entry(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
