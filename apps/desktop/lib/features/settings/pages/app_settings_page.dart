import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation_domain/domain.dart';

import '../controller/settings_controller.dart';
import '../widgets/dropdown_tile.dart';
import '../widgets/settings_group.dart';
import '../widgets/toggle_tile.dart';

class AppSettingsPage extends ConsumerWidget {
  const AppSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('APP 设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (state.errorMessage != null)
            Card(
              color: Colors.red.withValues(alpha: 0.15),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(state.errorMessage!),
              ),
            ),
          SettingsGroup(
            title: '通用',
            children: [
              DropdownTile<String>(
                title: '语言',
                value: state.app.locale,
                leading: const Icon(Icons.language),
                items: const [
                  DropdownMenuItem(value: 'system', child: Text('跟随系统')),
                  DropdownMenuItem(value: 'zh-CN', child: Text('中文简体')),
                  DropdownMenuItem(value: 'en', child: Text('English')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    controller.setLocale(value);
                  }
                },
              ),
              DropdownTile<AppThemeMode>(
                title: '外观',
                value: state.app.themeMode,
                leading: const Icon(Icons.dark_mode_outlined),
                items: const [
                  DropdownMenuItem(
                    value: AppThemeMode.system,
                    child: Text('跟随系统'),
                  ),
                  DropdownMenuItem(
                    value: AppThemeMode.light,
                    child: Text('浅色'),
                  ),
                  DropdownMenuItem(
                    value: AppThemeMode.dark,
                    child: Text('深色'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    controller.setThemeMode(value);
                  }
                },
              ),
            ],
          ),
          SettingsGroup(
            title: '开发与诊断',
            children: [
              ToggleTile(
                title: '导入调试日志',
                subtitle: '生成 debug-import.json，便于排查导入问题',
                leading: const Icon(Icons.bug_report_outlined),
                value: state.app.debugImport,
                onChanged: controller.setDebugImport,
              ),
              ToggleTile(
                title: '自动检查更新',
                leading: const Icon(Icons.system_update_alt),
                value: state.app.autoCheckUpdate,
                onChanged: (v) => controller.updateApp(
                  state.app.copyWith(autoCheckUpdate: v),
                ),
              ),
              ToggleTile(
                title: '发送匿名使用数据',
                leading: const Icon(Icons.privacy_tip_outlined),
                value: state.app.sendAnonymousUsage,
                onChanged: (v) => controller.updateApp(
                  state.app.copyWith(sendAnonymousUsage: v),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
