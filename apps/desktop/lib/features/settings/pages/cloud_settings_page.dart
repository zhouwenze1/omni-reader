import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../di/services_providers.dart';
import '../../../l10n/app_localizations.dart';
import '../widgets/cloud_backup_section.dart';
import 'package:shared_ui/shared_ui.dart';

/// 桌面端云端设置页:连接(阅读同步) + 书库云备份。
class CloudSettingsPage extends ConsumerWidget {
  const CloudSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.cloudSettings)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SyncSettingsSection(
            service: ref.read(syncServiceProvider),
            dataSync: ref.read(dataSyncServiceProvider),
          ),
          DataSyncSection(service: ref.read(dataSyncServiceProvider)),
          const CloudBackupSection(),
        ],
      ),
    );
  }
}
