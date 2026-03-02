import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation_domain/domain.dart';

import '../../../di/repositories_providers.dart';

class CloudSettingsPage extends ConsumerStatefulWidget {
  const CloudSettingsPage({super.key});

  @override
  ConsumerState<CloudSettingsPage> createState() => _CloudSettingsPageState();
}

class _CloudSettingsPageState extends ConsumerState<CloudSettingsPage> {
  CloudOptions _settings = const CloudOptions();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final value = await ref.read(settingsRepositoryProvider).getCloudOptions();
    if (!mounted) return;
    setState(() {
      _settings = value;
      _loading = false;
    });
  }

  Future<void> _save(CloudOptions value) async {
    setState(() => _settings = value);
    await ref.read(settingsRepositoryProvider).saveCloudOptions(value);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('云端设置')),
      body: ListView(
        children: [
          SwitchListTile(
            value: _settings.autoSync,
            onChanged: (v) => _save(_settings.copyWith(autoSync: v)),
            title: const Text('自动同步'),
          ),
          SwitchListTile(
            value: _settings.storeProgress,
            onChanged: (v) => _save(_settings.copyWith(storeProgress: v)),
            title: const Text('存储阅读进度'),
          ),
          SwitchListTile(
            value: _settings.storeNotes,
            onChanged: (v) => _save(_settings.copyWith(storeNotes: v)),
            title: const Text('存储笔记'),
          ),
        ],
      ),
    );
  }
}
