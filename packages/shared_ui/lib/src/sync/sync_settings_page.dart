import 'package:flutter/material.dart';
import 'package:services_sync/services_sync.dart';

/// 双端共用的"阅读同步"设置页。
///
/// 由宿主传入 [ProgressSyncService] 实例,页面负责读写配置、
/// 展示设备 ID、触发手动同步并显示同步状态。
class SyncSettingsPage extends StatefulWidget {
  const SyncSettingsPage({super.key, required this.service});

  final ProgressSyncService service;

  @override
  State<SyncSettingsPage> createState() => _SyncSettingsPageState();
}

class _SyncSettingsPageState extends State<SyncSettingsPage> {
  late final TextEditingController _serverUrlController;
  late final TextEditingController _tokenController;
  late final TextEditingController _deviceIdController;
  bool _syncing = false;
  String? _syncMessage;

  SyncConfig get _config => widget.service.getConfig();

  @override
  void initState() {
    super.initState();
    final config = _config;
    _serverUrlController = TextEditingController(text: config.serverUrl);
    _tokenController = TextEditingController(text: config.token);
    _deviceIdController = TextEditingController(text: config.deviceId);
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    _tokenController.dispose();
    _deviceIdController.dispose();
    super.dispose();
  }

  Future<void> _saveConfig() async {
    final current = _config;
    final next = current.copyWith(
      serverUrl: _serverUrlController.text.trim(),
      token: _tokenController.text.trim(),
      deviceId: _deviceIdController.text.trim().isEmpty
          ? _generateDeviceId()
          : _deviceIdController.text.trim(),
    );
    await widget.service.saveConfig(next);
    if (mounted) {
      _deviceIdController.text = next.deviceId;
    }
  }

  String _generateDeviceId() {
    // 简单随机 UUID v4。
    final random = DateTime.now().microsecondsSinceEpoch;
    final suffix = random.toRadixString(16).padLeft(12, '0');
    return 'dev-$suffix';
  }

  Future<void> _syncNow() async {
    await _saveConfig();
    setState(() {
      _syncing = true;
      _syncMessage = null;
    });
    final result = await widget.service.syncAll();
    if (!mounted) {
      return;
    }
    setState(() {
      _syncing = false;
      _syncMessage = '已同步:推送 ${result.pushed} 条,拉取 ${result.pulled} 条';
    });
  }

  @override
  Widget build(BuildContext context) {
    final config = _config;
    final lastSyncText = config.lastSyncAt == null
        ? '从未同步'
        : '上次同步:${config.lastSyncAt!.toLocal()}';

    return Scaffold(
      appBar: AppBar(title: const Text('阅读同步')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _serverUrlController,
            decoration: const InputDecoration(
              labelText: '服务器地址',
              hintText: 'http://192.168.1.100:8080',
              prefixIcon: Icon(Icons.dns_outlined),
            ),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tokenController,
            decoration: const InputDecoration(
              labelText: '同步 Token',
              prefixIcon: Icon(Icons.key_outlined),
            ),
            obscureText: true,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _deviceIdController,
            readOnly: true,
            decoration: const InputDecoration(
              labelText: '设备 ID',
              helperText: '首次保存自动生成,用于服务器区分设备',
              prefixIcon: Icon(Icons.phone_android_outlined),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _syncing ? null : _syncNow,
            icon: _syncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            label: Text(_syncing ? '同步中...' : '立即同步'),
          ),
          const SizedBox(height: 12),
          Text(
            _syncMessage ?? lastSyncText,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
