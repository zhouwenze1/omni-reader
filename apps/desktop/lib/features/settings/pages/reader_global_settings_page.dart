import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
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
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.readerSettings)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SettingsGroup(
            title: l10n.displaySettings,
            children: [
              SliderTile(
                title: l10n.fontSize,
                min: 12,
                max: 42,
                divisions: 30,
                value: reader.fontSize,
                valueText: reader.fontSize.toStringAsFixed(0),
                onChanged: (v) =>
                    controller.updateReader(reader.copyWith(fontSize: v)),
              ),
              SliderTile(
                title: l10n.lineHeight,
                min: 1.1,
                max: 2.4,
                divisions: 13,
                value: reader.lineHeight,
                valueText: reader.lineHeight.toStringAsFixed(2),
                onChanged: (v) =>
                    controller.updateReader(reader.copyWith(lineHeight: v)),
              ),
              SliderTile(
                title: l10n.pageGap,
                min: 0,
                max: 80,
                divisions: 16,
                value: reader.pageGap,
                valueText: reader.pageGap.toStringAsFixed(0),
                onChanged: (v) =>
                    controller.updateReader(reader.copyWith(pageGap: v)),
              ),
              DropdownTile<String>(
                title: l10n.theme,
                value: reader.theme,
                leading: const Icon(Icons.palette_outlined),
                items: [
                  DropdownMenuItem(value: 'day', child: Text(l10n.themeDay)),
                  DropdownMenuItem(
                      value: 'night', child: Text(l10n.themeNight)),
                  DropdownMenuItem(
                      value: 'sepia', child: Text(l10n.themeSepia)),
                ],
                onChanged: (value) {
                  if (value != null) {
                    controller.updateReader(reader.copyWith(theme: value));
                  }
                },
              ),
              DropdownTile<String>(
                title: l10n.layoutMode,
                value: reader.layoutMode,
                leading: const Icon(Icons.view_day_outlined),
                items: [
                  DropdownMenuItem(
                    value: 'paged_spread',
                    child: Text(l10n.layoutPaged),
                  ),
                  DropdownMenuItem(
                    value: 'scroll_boundary',
                    child: Text(l10n.layoutScroll),
                  ),
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
            title: l10n.layoutDetails,
            children: [
              ToggleTile(
                title: l10n.enableTextIndent,
                value: reader.textIndentEnabled,
                onChanged: (v) => controller.updateReader(
                  reader.copyWith(textIndentEnabled: v),
                ),
              ),
              SliderTile(
                title: l10n.indentSizeEm,
                min: 0,
                max: 4,
                divisions: 20,
                value: reader.textIndentEm,
                valueText: reader.textIndentEm.toStringAsFixed(1),
                onChanged: (v) =>
                    controller.updateReader(reader.copyWith(textIndentEm: v)),
              ),
              ToggleTile(
                title: l10n.skipFirstParagraphIndent,
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
