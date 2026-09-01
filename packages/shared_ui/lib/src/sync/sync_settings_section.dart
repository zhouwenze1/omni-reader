import 'package:flutter/material.dart';
import 'package:services_sync/services_sync.dart';

/// 云端设置页内的"阅读进度同步"配置区。
///
/// 卡片式设计:渐变头部 + 状态徽章 + 圆角输入框 + 渐变同步按钮,
/// 直接嵌入设置页,不再是独立页面。
class SyncSettingsSection extends StatefulWidget {
  const SyncSettingsSection({super.key, required this.service});

  final ProgressSyncService service;

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
      if (!mounted) {
        return;
      }
      setState(() {
        _syncMessage = '已同步:推送 ${result.pushed} 条,拉取 ${result.pulled} 条';
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final config = _config;
    final synced = config.lastSyncAt != null;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 0,
      color: colorScheme.surfaceContainerLowest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 渐变头部
          Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colorScheme.primaryContainer,
                  colorScheme.surfaceContainerHighest,
                ],
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.sync_rounded,
                    color: colorScheme.onPrimary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '阅读进度同步',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '多设备间同步阅读位置,自动续读',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusBadge(synced: synced, syncing: _syncing),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SyncField(
                  controller: _serverUrlController,
                  icon: Icons.dns_outlined,
                  label: '服务器地址',
                  hint: 'http://192.168.1.100:8080',
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 12),
                _SyncField(
                  controller: _tokenController,
                  icon: Icons.key_outlined,
                  label: '同步 Token',
                  obscure: _obscureToken,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureToken
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _obscureToken = !_obscureToken),
                  ),
                ),
                const SizedBox(height: 12),
                _SyncField(
                  controller: _deviceIdController,
                  icon: Icons.phone_android_outlined,
                  label: '设备 ID',
                  helper: '首次保存自动生成,用于服务器区分设备',
                  readOnly: true,
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: _syncing ? null : _syncNow,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _syncing
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.cloud_sync_outlined, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                '立即同步',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _syncMessage ??
                      (synced
                          ? '上次同步:${config.lastSyncAt!.toLocal()}'
                          : '从未同步'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _syncMessage?.contains('失败') == true
                        ? colorScheme.error
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.synced, required this.syncing});

  final bool synced;
  final bool syncing;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final Color background;
    final Color foreground;
    final String label;
    if (syncing) {
      background = colorScheme.surface.withValues(alpha: 0.8);
      foreground = colorScheme.primary;
      label = '同步中';
    } else if (synced) {
      background = colorScheme.primary.withValues(alpha: 0.12);
      foreground = colorScheme.primary;
      label = '已连接';
    } else {
      background = colorScheme.surface.withValues(alpha: 0.7);
      foreground = colorScheme.onSurfaceVariant;
      label = '未配置';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (syncing)
            const SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(strokeWidth: 1.8),
            )
          else
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: foreground,
                shape: BoxShape.circle,
              ),
            ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncField extends StatelessWidget {
  const _SyncField({
    required this.controller,
    required this.icon,
    required this.label,
    this.hint,
    this.helper,
    this.obscure = false,
    this.readOnly = false,
    this.suffixIcon,
    this.keyboardType,
  });

  final TextEditingController controller;
  final IconData icon;
  final String label;
  final String? hint;
  final String? helper;
  final bool obscure;
  final bool readOnly;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      obscureText: obscure,
      readOnly: readOnly,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        prefixIcon: Icon(icon, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: colorScheme.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
      ),
    );
  }
}
