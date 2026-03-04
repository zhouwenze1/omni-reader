import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
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
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.cloudSettings)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SettingsGroup(
            title: l10n.cloudService,
            children: [
              DropdownTile<String>(
                title: l10n.storageProvider,
                leading: const Icon(Icons.cloud_queue),
                value: cloud.provider,
                items: [
                  DropdownMenuItem(
                      value: 'none', child: Text(l10n.disconnected)),
                  const DropdownMenuItem(
                    value: 'gdrive',
                    child: Text('Google Drive'),
                  ),
                  const DropdownMenuItem(
                    value: 'onedrive',
                    child: Text('OneDrive'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    controller.updateCloud(cloud.copyWith(provider: value));
                  }
                },
              ),
              ToggleTile(
                title: l10n.autoSync,
                value: cloud.autoSync,
                onChanged: (v) => controller.updateCloud(
                  cloud.copyWith(autoSync: v),
                ),
              ),
            ],
          ),
          SettingsGroup(
            title: l10n.advancedOptions,
            children: [
              ToggleTile(
                title: l10n.storeOriginalFiles,
                value: cloud.storeOriginalFiles,
                onChanged: (v) => controller.updateCloud(
                  cloud.copyWith(storeOriginalFiles: v),
                ),
              ),
              ToggleTile(
                title: l10n.storeProgress,
                value: cloud.storeProgress,
                onChanged: (v) => controller.updateCloud(
                  cloud.copyWith(storeProgress: v),
                ),
              ),
              ToggleTile(
                title: l10n.storeNotes,
                value: cloud.storeNotes,
                onChanged: (v) => controller.updateCloud(
                  cloud.copyWith(storeNotes: v),
                ),
              ),
              ToggleTile(
                title: l10n.storeHighlights,
                value: cloud.storeHighlights,
                onChanged: (v) => controller.updateCloud(
                  cloud.copyWith(storeHighlights: v),
                ),
              ),
              ToggleTile(
                title: l10n.storeAppData,
                value: cloud.storeAppData,
                onChanged: (v) => controller.updateCloud(
                  cloud.copyWith(storeAppData: v),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
