import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controller/settings_controller.dart';
import '../widgets/dropdown_tile.dart';
import '../widgets/settings_group.dart';
import '../widgets/toggle_tile.dart';

class CloudSettingsPage extends ConsumerWidget {
  const CloudSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);
    final cloud = state.cloud;

    return Scaffold(
      appBar: AppBar(title: const Text('云端设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SettingsGroup(
            title: '连接',
            children: [
              DropdownTile<String>(
                title: '存储提供方',
                leading: const Icon(Icons.cloud_queue_outlined),
                value: cloud.provider,
                items: const [
                  DropdownMenuItem(value: 'none', child: Text('未连接')),
                  DropdownMenuItem(value: 'gdrive', child: Text('Google Drive')),
                  DropdownMenuItem(value: 'onedrive', child: Text('OneDrive')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    controller.updateCloud(cloud.copyWith(provider: value));
                  }
                },
              ),
              ToggleTile(
                title: '自动同步',
                leading: const Icon(Icons.sync_outlined),
                value: cloud.autoSync,
                onChanged: (v) =>
                    controller.updateCloud(cloud.copyWith(autoSync: v)),
              ),
            ],
          ),
          SettingsGroup(
            title: '同步内容',
            children: [
              ToggleTile(
                title: '同步原始文件',
                value: cloud.storeOriginalFiles,
                onChanged: (v) => controller.updateCloud(
                  cloud.copyWith(storeOriginalFiles: v),
                ),
              ),
              ToggleTile(
                title: '同步阅读进度',
                value: cloud.storeProgress,
                onChanged: (v) =>
                    controller.updateCloud(cloud.copyWith(storeProgress: v)),
              ),
              ToggleTile(
                title: '同步笔记',
                value: cloud.storeNotes,
                onChanged: (v) =>
                    controller.updateCloud(cloud.copyWith(storeNotes: v)),
              ),
              ToggleTile(
                title: '同步高亮',
                value: cloud.storeHighlights,
                onChanged: (v) =>
                    controller.updateCloud(cloud.copyWith(storeHighlights: v)),
              ),
              ToggleTile(
                title: '同步应用数据',
                value: cloud.storeAppData,
                onChanged: (v) =>
                    controller.updateCloud(cloud.copyWith(storeAppData: v)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
