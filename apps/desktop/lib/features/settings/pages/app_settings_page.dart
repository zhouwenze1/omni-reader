import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation_domain/domain.dart';

import '../../../l10n/app_localizations.dart';
import '../controller/settings_controller.dart';
import 'package:shared_ui/shared_ui.dart';
import '../widgets/settings_group.dart';
import '../widgets/toggle_tile.dart';

class AppSettingsPage extends ConsumerWidget {
  const AppSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.appSettings)),
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
            title: l10n.general,
            children: [
              DropdownTile<String>(
                title: l10n.language,
                value: state.app.locale,
                leading: const Icon(Icons.language),
                items: [
                  DropdownMenuItem(
                    value: 'system',
                    child: Text(l10n.followSystem),
                  ),
                  DropdownMenuItem(
                    value: 'zh-CN',
                    child: Text(l10n.chineseSimplified),
                  ),
                  DropdownMenuItem(value: 'en', child: Text(l10n.english)),
                ],
                onChanged: (value) {
                  if (value != null) {
                    controller.setLocale(value);
                  }
                },
              ),
              DropdownTile<AppThemeMode>(
                title: l10n.appearance,
                value: state.app.themeMode,
                leading: const Icon(Icons.dark_mode_outlined),
                items: [
                  DropdownMenuItem(
                    value: AppThemeMode.system,
                    child: Text(l10n.followSystem),
                  ),
                  DropdownMenuItem(
                    value: AppThemeMode.light,
                    child: Text(l10n.lightTheme),
                  ),
                  DropdownMenuItem(
                    value: AppThemeMode.dark,
                    child: Text(l10n.darkTheme),
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
            title: l10n.diagnostics,
            children: [
              ToggleTile(
                title: l10n.debugImportLogs,
                subtitle: l10n.debugImportLogsSubtitle,
                leading: const Icon(Icons.bug_report_outlined),
                value: state.app.debugImport,
                onChanged: controller.setDebugImport,
              ),
              ToggleTile(
                title: l10n.autoCheckUpdate,
                leading: const Icon(Icons.system_update_alt),
                value: state.app.autoCheckUpdate,
                onChanged: (v) => controller.updateApp(
                  state.app.copyWith(autoCheckUpdate: v),
                ),
              ),
              ToggleTile(
                title: l10n.sendAnonymousUsage,
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
