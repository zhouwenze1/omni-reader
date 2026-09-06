import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:services_sync/services_sync.dart';

import '../../../di/services_providers.dart';
import '../widgets/settings_group.dart';

/// 移动端"书库云备份"设置区:状态/立即备份/仅 Wi-Fi/自动释放。
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
    final manager = ref.watch(bookCloudManagerProvider);
    final config = manager.config;
    final counts = _counts;

    return SettingsGroup(
      title: '书库云备份',
      children: [
        ListTile(
          leading: const Icon(Icons.cloud_done_outlined),
          title: counts == null
              ? const Text('…')
              : Text(
                  '已备份 ${counts.backedUp} 本 · 待上传 ${counts.pending} 本 · 仅云端 ${counts.cloudOnly} 本',
                ),
        ),
        ListTile(
          leading: const Icon(Icons.backup_outlined),
          title: const Text('立即备份未备份的书'),
          onTap: () async {
            final messenger = ScaffoldMessenger.of(context);
            final uploaded =
                await ref.read(bookCloudManagerProvider).backupPendingBooks();
            await _refreshCounts();
            messenger.showSnackBar(
              SnackBar(content: Text('已备份 $uploaded 本书')),
            );
          },
        ),
        SwitchListTile(
          secondary: const Icon(Icons.wifi_outlined),
          title: const Text('仅 Wi-Fi 上传/下载'),
          value: config.wifiOnly,
          onChanged: (value) async {
            await manager.updateConfig((c) => c.copyWith(wifiOnly: value));
            setState(() {});
          },
        ),
        SwitchListTile(
          secondary: const Icon(Icons.auto_delete_outlined),
          title: const Text('自动释放 N 天未读的书'),
          subtitle: Text('释放后书架保留,点开自动取回(当前 ${config.autoEvictDays} 天)'),
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
          title: const Text('释放阈值(天)'),
          trailing: Text('${config.autoEvictDays} 天'),
          onTap: () async {
            final days = await _pickDays(config.autoEvictDays);
            if (days != null) {
              await manager.updateConfig((c) => c.copyWith(autoEvictDays: days));
              setState(() {});
            }
          },
        ),
      ],
    );
  }

  Future<int?> _pickDays(int current) {
    const options = [7, 14, 30, 60, 90];
    return showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('释放阈值(天)'),
        children: [
          for (final days in options)
            ListTile(
              leading: days == current
                  ? const Icon(Icons.check)
                  : const SizedBox(width: 24),
              title: Text('$days 天'),
              onTap: () => Navigator.of(context).pop(days),
            ),
        ],
      ),
    );
  }
}
