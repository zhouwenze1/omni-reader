import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation_domain/domain.dart';

import '../../../di/repositories_providers.dart';

class AppSettingsPage extends ConsumerStatefulWidget {
  const AppSettingsPage({super.key});

  @override
  ConsumerState<AppSettingsPage> createState() => _AppSettingsPageState();
}

class _AppSettingsPageState extends ConsumerState<AppSettingsPage> {
  AppSettings _settings = const AppSettings();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final value = await ref.read(settingsRepositoryProvider).getAppSettings();
    if (!mounted) return;
    setState(() {
      _settings = value;
      _loading = false;
    });
  }

  Future<void> _save(AppSettings value) async {
    setState(() => _settings = value);
    await ref.read(settingsRepositoryProvider).saveAppSettings(value);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('APP 设置')),
      body: ListView(
        children: [
          SwitchListTile(
            value: _settings.themeMode == AppThemeMode.dark,
            onChanged: (v) => _save(_settings.copyWith(
              themeMode: v ? AppThemeMode.dark : AppThemeMode.light,
            )),
            title: const Text('夜间模式'),
          ),
          SwitchListTile(
            value: _settings.debugImport,
            onChanged: (v) => _save(_settings.copyWith(debugImport: v)),
            title: const Text('导入调试日志'),
          ),
        ],
      ),
    );
  }
}
