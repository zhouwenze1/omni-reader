import 'package:flutter/material.dart';
import 'package:services_sync/services_sync.dart';

/// 云端设置页内的"阅读同步"配置区。
///
/// 简洁设计:一个可展开的设置项,点击展开显示服务器地址/Token/设备 ID
/// 与同步按钮,再点收起;不点击不显示内容。
class SyncSettingsSection extends StatefulWidget {
  const SyncSettingsSection({super.key, required this.service, this.dataSync});

  final ProgressSyncService service;

  /// 非空时"立即同步"同时同步标注/设置/统计(v2 实体)。
  final DataSyncService? dataSync;

  @override
  State<SyncSettingsSection> createState() => _SyncSettingsSectionState();
}

class _SyncSettingsSectionState extends State<SyncSettingsSection> {
  late final TextEditingController _serverUrlController;
  late final TextEditingController _tokenController;
  late final TextEditingController _deviceIdController;
  bool _obscureToken = true;
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
    try {
      final result = await widget.service.syncAll();
      var pushed = result.pushed;
      var pulled = result.pulled;
      Object? dataSyncError = result.error;
      final dataSync = widget.dataSync;
      if (dataSync != null) {
        final dataResult = await dataSync.syncAll();
        pushed += dataResult.pushed;
        pulled += dataResult.pulled;
        dataSyncError ??= dataResult.error;
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _syncMessage = dataSyncError != null
            ? '同步失败:$dataSyncError'
            : '已同步:推送 $pushed 条,拉取 $pulled 条';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _syncMessage = '同步失败:$error';
      });
    } finally {
      if (mounted) {
        setState(() => _syncing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = _config;
    final synced = config.lastSyncAt != null;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: const Icon(Icons.sync),
        title: const Text('阅读同步'),
        subtitle: Text(
          synced
              ? '上次同步:${config.lastSyncAt!.toLocal()}'
              : (config.isConfigured ? '已配置,尚未成功同步' : '未配置'),
        ),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('自动同步'),
            subtitle: Text(
              config.isConfigured ? '启动/开关书时自动同步' : '未配置服务器,自动同步不可用',
            ),
            value: config.isConfigured && config.autoSync,
            onChanged: config.isConfigured
                ? (value) async {
                    await widget.service.saveConfig(
                      widget.service.getConfig().copyWith(autoSync: value),
                    );
                    setState(() {});
                  }
                : null,
          ),
          TextField(
            controller: _serverUrlController,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: '服务器地址',
              hintText: 'http://192.168.1.100:8080',
              prefixIcon: Icon(Icons.dns_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tokenController,
            obscureText: _obscureToken,
            decoration: InputDecoration(
              labelText: '同步 Token',
              prefixIcon: const Icon(Icons.key_outlined),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureToken
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () => setState(() => _obscureToken = !_obscureToken),
              ),
            ),
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
          const SizedBox(height: 16),
          SizedBox(
            height: 44,
            child: FilledButton.icon(
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
          ),
          if (_syncMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _syncMessage!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _syncMessage!.contains('失败')
                        ? Theme.of(context).colorScheme.error
                        : null,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}
