import 'package:flutter/material.dart';

import '../widgets/settings_group.dart';
import '../widgets/toggle_tile.dart';

class ReadingAssistSettingsPage extends StatefulWidget {
  const ReadingAssistSettingsPage({super.key});

  @override
  State<ReadingAssistSettingsPage> createState() =>
      _ReadingAssistSettingsPageState();
}

class _ReadingAssistSettingsPageState
    extends State<ReadingAssistSettingsPage> {
  bool _dictionary = true;
  bool _translation = false;
  bool _tts = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('阅读辅助')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SettingsGroup(
            title: '快捷辅助',
            children: [
              ToggleTile(
                title: '启用词典面板',
                value: _dictionary,
                onChanged: (value) => setState(() => _dictionary = value),
              ),
              ToggleTile(
                title: '启用翻译面板',
                value: _translation,
                onChanged: (value) => setState(() => _translation = value),
              ),
              ToggleTile(
                title: '启用朗读面板',
                value: _tts,
                onChanged: (value) => setState(() => _tts = value),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
