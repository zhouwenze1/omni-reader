import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:services_sync/services_sync.dart';

import '../../../di/services_providers.dart';
import '../../../l10n/app_localizations.dart';
import '../widgets/settings_group.dart';

/// 桌面端"书库云备份"设置区:状态/立即备份/自动释放(桌面无 Wi-Fi 限制)。
class CloudBackupSection extends ConsumerStatefulWidget {
  const CloudBackupSection({super.key});

  @override
  ConsumerState<CloudBackupSection> createState() => _CloudBackupSectionState();
}

class _CloudBackupSectionState extends ConsumerState<CloudBackupSection> {
  CloudLibraryCounts? _counts;

  @override
  void initState() {
    super.initState();
    _refreshCounts();
  }

  Future<void> _refreshCounts() async {
    final counts = await ref.read(bookCloudManagerProvider).counts();
    if (mounted) {
      setState(() => _counts = counts);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final manager = ref.watch(bookCloudManagerProvider);
    final config = manager.config;
    final counts = _counts;

    return SettingsGroup(
      title: l10n.cloudBackupTitle,
      children: [
        ListTile(
          leading: const Icon(Icons.cloud_done_outlined),
          title: counts == null
              ? const Text('…')
              : Text(
                  '${l10n.backedUpLabel} ${counts.backedUp} · '
                  '${l10n.pendingUploadLabel} ${counts.pending} · '
                  '${l10n.cloudOnlyLabel} ${counts.cloudOnly}',
                ),
        ),
        ListTile(
          leading: const Icon(Icons.backup_outlined),
          title: Text(l10n.backupNow),
          onTap: () async {
            final messenger = ScaffoldMessenger.of(context);
            final uploaded =
                await ref.read(bookCloudManagerProvider).backupPendingBooks();
            await _refreshCounts();
            messenger.showSnackBar(
              SnackBar(content: Text('${l10n.backupDone}: $uploaded')),
            );
          },
        ),
        SwitchListTile(
          secondary: const Icon(Icons.auto_delete_outlined),
          title: Text(l10n.autoReleaseOldBooks),
          subtitle: Text('${config.autoEvictDays} d'),
          value: config.autoEvictEnabled,
          onChanged: (value) async {
            await manager.updateConfig(
              (c) => c.copyWith(autoEvictEnabled: value),
            );
            setState(() {});
          },
        ),
        ListTile(
          leading: const Icon(Icons.timer_outlined),
          title: Text('${l10n.autoReleaseOldBooks} (d)'),
          trailing: Text('${config.autoEvictDays} d'),
          onTap: () async {
            final days = await _pickDays(config.autoEvictDays, l10n);
            if (days != null) {
              await manager.updateConfig((c) => c.copyWith(autoEvictDays: days));
              setState(() {});
            }
          },
        ),
      ],
    );
  }

  Future<int?> _pickDays(int current, AppLocalizations l10n) {
    const options = [7, 14, 30, 60, 90];
    return showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.autoReleaseOldBooks),
        children: [
          for (final days in options)
            ListTile(
              leading: days == current
                  ? const Icon(Icons.check)
                  : const SizedBox(width: 24),
              title: Text('$days d'),
              onTap: () => Navigator.of(context).pop(days),
            ),
        ],
      ),
    );
  }
}
