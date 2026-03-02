import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation_domain/domain.dart';

import '../../../di/repositories_providers.dart';

class ReaderGlobalSettingsPage extends ConsumerStatefulWidget {
  const ReaderGlobalSettingsPage({super.key});

  @override
  ConsumerState<ReaderGlobalSettingsPage> createState() =>
      _ReaderGlobalSettingsPageState();
}

class _ReaderGlobalSettingsPageState
    extends ConsumerState<ReaderGlobalSettingsPage> {
  ReaderSettings _settings = const ReaderSettings();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final value = await ref.read(settingsRepositoryProvider).getReaderSettings();
    if (!mounted) return;
    setState(() {
      _settings = value;
      _loading = false;
    });
  }

  Future<void> _save(ReaderSettings value) async {
    setState(() => _settings = value);
    await ref.read(settingsRepositoryProvider).saveReaderSettings(value);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('阅读器设置')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('字体大小'),
            subtitle: Slider(
              min: 12,
              max: 42,
              value: _settings.fontSize,
              onChanged: (v) => _save(_settings.copyWith(fontSize: v)),
            ),
            trailing: Text(_settings.fontSize.toStringAsFixed(0)),
          ),
          ListTile(
            title: const Text('行高'),
            subtitle: Slider(
              min: 1.1,
              max: 2.4,
              value: _settings.lineHeight,
              onChanged: (v) => _save(_settings.copyWith(lineHeight: v)),
            ),
            trailing: Text(_settings.lineHeight.toStringAsFixed(2)),
          ),
        ],
      ),
    );
  }
}
