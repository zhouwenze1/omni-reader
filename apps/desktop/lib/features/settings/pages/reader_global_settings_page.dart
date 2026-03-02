import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controller/settings_controller.dart';
import '../widgets/dropdown_tile.dart';
import '../widgets/settings_group.dart';
import '../widgets/slider_tile.dart';
import '../widgets/toggle_tile.dart';

class ReaderGlobalSettingsPage extends ConsumerWidget {
  const ReaderGlobalSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);
    final reader = state.reader;

    return Scaffold(
      appBar: AppBar(title: const Text('阅读器设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SettingsGroup(
            title: '显示设置',
            children: [
              SliderTile(
                title: '字体大小',
                min: 12,
                max: 42,
                divisions: 30,
                value: reader.fontSize,
                valueText: reader.fontSize.toStringAsFixed(0),
                onChanged: (v) => controller.updateReader(reader.copyWith(fontSize: v)),
              ),
              SliderTile(
                title: '行高',
                min: 1.1,
                max: 2.4,
                divisions: 13,
                value: reader.lineHeight,
                valueText: reader.lineHeight.toStringAsFixed(2),
                onChanged: (v) => controller.updateReader(reader.copyWith(lineHeight: v)),
              ),
              SliderTile(
                title: '页间距',
                min: 0,
                max: 80,
                divisions: 16,
                value: reader.pageGap,
                valueText: reader.pageGap.toStringAsFixed(0),
                onChanged: (v) => controller.updateReader(reader.copyWith(pageGap: v)),
              ),
              DropdownTile<String>(
                title: '主题',
                value: reader.theme,
                leading: const Icon(Icons.palette_outlined),
                items: const [
                  DropdownMenuItem(value: 'day', child: Text('日间')),
                  DropdownMenuItem(value: 'night', child: Text('夜间')),
                  DropdownMenuItem(value: 'sepia', child: Text('护眼')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    controller.updateReader(reader.copyWith(theme: value));
                  }
                },
              ),
              DropdownTile<String>(
                title: '分页模式',
                value: reader.layoutMode,
                leading: const Icon(Icons.view_day_outlined),
                items: const [
                  DropdownMenuItem(value: 'paged_spread', child: Text('分页')),
                  DropdownMenuItem(value: 'scroll_boundary', child: Text('滚动')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    controller.updateReader(reader.copyWith(layoutMode: value));
                  }
                },
              ),
            ],
          ),
          SettingsGroup(
            title: '排版细节',
            children: [
              ToggleTile(
                title: '启用首行缩进',
                value: reader.textIndentEnabled,
                onChanged: (v) => controller.updateReader(
                  reader.copyWith(textIndentEnabled: v),
                ),
              ),
              SliderTile(
                title: '缩进大小 (em)',
                min: 0,
                max: 4,
                divisions: 20,
                value: reader.textIndentEm,
                valueText: reader.textIndentEm.toStringAsFixed(1),
                onChanged: (v) => controller.updateReader(reader.copyWith(textIndentEm: v)),
              ),
              ToggleTile(
                title: '首段不缩进',
                value: reader.textIndentSkipFirstParagraph,
                onChanged: (v) => controller.updateReader(
                  reader.copyWith(textIndentSkipFirstParagraph: v),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
