import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation_domain/domain.dart';

import '../../../l10n/l10n.dart';
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
            title: l10n.display,
            children: [
              SliderTile(
                title: l10n.fontSize,
                min: 12,
                max: 42,
                divisions: 30,
                value: reader.fontSize,
                valueText: reader.fontSize.toStringAsFixed(0),
                onChanged: (value) =>
                    controller.updateReader(reader.copyWith(fontSize: value)),
              ),
              SliderTile(
                title: l10n.lineHeight,
                min: 1.1,
                max: 2.4,
                divisions: 13,
                value: reader.lineHeight,
                valueText: reader.lineHeight.toStringAsFixed(2),
                onChanged: (value) => controller.updateReader(
                  reader.copyWith(lineHeight: value),
                ),
              ),
              SliderTile(
                title: l10n.pageGap,
                min: 0,
                max: 80,
                divisions: 16,
                value: reader.pageGap,
                valueText: reader.pageGap.toStringAsFixed(0),
                onChanged: (value) =>
                    controller.updateReader(reader.copyWith(pageGap: value)),
              ),
              DropdownTile<String>(
                title: l10n.theme,
                value: reader.rendererTheme,
                leading: const Icon(Icons.palette_outlined),
                items: [
                  DropdownMenuItem(value: 'day', child: Text(l10n.dayTheme)),
                  DropdownMenuItem(
                    value: 'night',
                    child: Text(l10n.nightTheme),
                  ),
                  DropdownMenuItem(
                    value: 'sepia',
                    child: Text(l10n.sepiaTheme),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    controller.updateReader(
                      reader.copyWith(rendererTheme: value),
                    );
                  }
                },
              ),
              DropdownTile<String>(
                title: l10n.layoutMode,
                value: reader.layoutMode,
                leading: const Icon(Icons.view_day_outlined),
                items: [
                  DropdownMenuItem(
                    value: ReaderLayoutMode.pagedAuto,
                    child: Text(l10n.layoutAuto),
                  ),
                  DropdownMenuItem(
                    value: ReaderLayoutMode.pagedSingle,
                    child: Text(l10n.layoutSingle),
                  ),
                  DropdownMenuItem(
                    value: ReaderLayoutMode.pagedSpread,
                    child: Text(l10n.layoutSpread),
                  ),
                  DropdownMenuItem(
                    value: ReaderLayoutMode.scrollBoundary,
                    child: Text(l10n.layoutBoundary),
                  ),
                  DropdownMenuItem(
                    value: ReaderLayoutMode.scrollContinuous,
                    child: Text(l10n.layoutContinuous),
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
            title: l10n.typography,
            children: [
              ToggleTile(
                title: l10n.enableTextIndent,
                value: reader.textIndentEnabled,
                onChanged: (value) => controller.updateReader(
                  reader.copyWith(textIndentEnabled: value),
                ),
              ),
              SliderTile(
                title: l10n.indentSize,
                min: 0,
                max: 4,
                divisions: 20,
                value: reader.textIndentEm,
                valueText: '${reader.textIndentEm.toStringAsFixed(1)}em',
                onChanged: (value) =>
                    controller.updateReader(reader.copyWith(textIndentEm: value)),
              ),
              ToggleTile(
                title: l10n.skipFirstParagraphIndent,
                value: reader.textIndentSkipFirstParagraph,
                onChanged: (value) => controller.updateReader(
                  reader.copyWith(textIndentSkipFirstParagraph: value),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
