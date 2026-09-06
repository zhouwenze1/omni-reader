import 'package:flutter/material.dart';

import 'package:services_sync/services_sync.dart';

/// 同步内容开关 + WebDAV 文件后端配置(两端共用)。
///
/// 开关与 WebDAV 配置直接写 SyncConfig 持久化,实时生效:
/// 标注/设置/统计按开关参与双向同步;启用 WebDAV 后书文件上传/取回
/// 改走用户自有 WebDAV,书单/封面/进度/标注仍走自建服务器。
class DataSyncSection extends StatefulWidget {
  const DataSyncSection({super.key, required this.service});

  final DataSyncService service;

  @override
  State<DataSyncSection> createState() => _DataSyncSectionState();
}

class _DataSyncSectionState extends State<DataSyncSection> {
  late final TextEditingController _webdavUrlController;
  late final TextEditingController _webdavUser;
  late final TextEditingController _webdavPassword;
  bool _obscurePassword = true;
  bool _testing = false;
  String? _testMessage;

  SyncConfig get _config => widget.service.getConfig();

  @override
  void initState() {
    super.initState();
    final config = _config;
    _webdavUrlController = TextEditingController(text: config.webdavUrl);
    _webdavUser = TextEditingController(text: config.webdavUsername);
    _webdavPassword = TextEditingController(text: config.webdavPassword);
  }

  @override
  void dispose() {
    _webdavUrlController.dispose();
    _webdavUser.dispose();
    _webdavPassword.dispose();
    super.dispose();
  }

  Future<void> _saveConfig(SyncConfig config) async {
    await widget.service.saveConfig(config);
    if (mounted) setState(() {});
  }

  Future<void> _testWebdav() async {
    setState(() {
      _testing = true;
      _testMessage = null;
    });
    try {
      final backend = WebDavFilesBackend(
        baseUrl: _webdavUrlController.text.trim(),
        username: _webdavUser.text.trim(),
        password: _webdavPassword.text,
      );
      await backend.testConnection();
      if (mounted) setState(() => _testMessage = '连接成功');
    } catch (error) {
      if (mounted) setState(() => _testMessage = '连接失败:$error');
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = _config;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: const Icon(Icons.tune),
        title: const Text('同步内容'),
        subtitle: Text(
          '标注${config.syncAnnotations ? '开' : '关'} · '
          '阅读设置${config.syncSettings ? '开' : '关'} · '
          '阅读统计${config.syncStats ? '开' : '关'}'
          '${config.webdavEnabled ? ' · WebDAV 已启用' : ''}',
        ),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('书签 / 划线 / 笔记'),
            subtitle: const Text('按书双向合并,删除传播到所有设备'),
            value: config.syncAnnotations,
            onChanged: (value) => _saveConfig(
              widget.service.getConfig().copyWith(syncAnnotations: value),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('阅读设置'),
            subtitle: const Text('字号 / 行距 / 主题 / 排版等全局阅读偏好'),
            value: config.syncSettings,
            onChanged: (value) => _saveConfig(
              widget.service.getConfig().copyWith(syncSettings: value),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('阅读统计'),
            subtitle: const Text('各设备阅读时长按会话合并到统计中心'),
            value: config.syncStats,
            onChanged: (value) => _saveConfig(
              widget.service.getConfig().copyWith(syncStats: value),
            ),
          ),
          const Divider(height: 24),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('WebDAV 文件后端'),
            subtitle: const Text(
              '书文件改存到你的 WebDAV(坚果云等);'
              '书单、封面、进度、标注仍走同步服务器',
            ),
            value: config.webdavEnabled,
            onChanged: (value) async {
              await _saveConfig(
                widget.service.getConfig().copyWith(
                      webdavEnabled: value,
                      webdavUrl: _webdavUrlController.text.trim(),
                      webdavUsername: _webdavUser.text.trim(),
                      webdavPassword: _webdavPassword.text,
                    ),
              );
            },
          ),
          if (config.webdavEnabled) ...[
            TextField(
              controller: _webdavUrlController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'WebDAV 地址',
                hintText: 'https://dav.jianguoyun.com/dav/',
                prefixIcon: Icon(Icons.cloud_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _webdavUser,
              decoration: const InputDecoration(
                labelText: '账号',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _webdavPassword,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: '密码 / 应用密码',
                prefixIcon: const Icon(Icons.password_outlined),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _testing ? null : _testWebdav,
                  icon: _testing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.network_check),
                  label: const Text('测试连接'),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: () async {
                    await _saveConfig(
                      widget.service.getConfig().copyWith(
                            webdavUrl: _webdavUrlController.text.trim(),
                            webdavUsername: _webdavUser.text.trim(),
                            webdavPassword: _webdavPassword.text,
                          ),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('WebDAV 配置已保存')),
                      );
                    }
                  },
                  child: const Text('保存'),
                ),
              ],
            ),
            if (_testMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _testMessage!,
                style: TextStyle(
                  color: _testMessage!.contains('失败')
                      ? Theme.of(context).colorScheme.error
                      : null,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              '文件将存放在 WebDAV 的 omni-books/<书籍ID>/ 目录,'
              '请在网盘应用中生成应用密码后使用。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
