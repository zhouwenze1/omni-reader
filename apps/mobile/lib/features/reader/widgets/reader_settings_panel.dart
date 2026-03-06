import 'package:flutter/material.dart';
import 'package:foundation_domain/domain.dart';

import '../../../l10n/l10n.dart';

class ReaderSettingsPanel extends StatelessWidget {
  const ReaderSettingsPanel({
    super.key,
    required this.settings,
    required this.onChanged,
  });

  final ReaderSettings settings;
  final ValueChanged<ReaderSettings> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.readerSettings,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              _slider(
                title: l10n.fontSize,
                value: settings.fontSize,
                min: 12,
                max: 42,
                onChanged: (value) =>
                    onChanged(settings.copyWith(fontSize: value)),
              ),
              _slider(
                title: l10n.lineHeight,
                value: settings.lineHeight,
                min: 1.1,
                max: 2.4,
                onChanged: (value) =>
                    onChanged(settings.copyWith(lineHeight: value)),
              ),
              _slider(
                title: l10n.pageGap,
                value: settings.pageGap,
                min: 0,
                max: 80,
                onChanged: (value) =>
                    onChanged(settings.copyWith(pageGap: value)),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: settings.rendererTheme,
                decoration: InputDecoration(labelText: l10n.theme),
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
                    onChanged(settings.copyWith(rendererTheme: value));
                  }
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: settings.layoutMode,
                decoration: InputDecoration(labelText: l10n.layoutMode),
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
                    onChanged(settings.copyWith(layoutMode: value));
                  }
                },
              ),
              const SizedBox(height: 8),
              Text(
                l10n.layoutAutoHint,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.enableTextIndent),
                value: settings.textIndentEnabled,
                onChanged: (value) => onChanged(
                  settings.copyWith(textIndentEnabled: value),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _slider({
    required String title,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(title)),
            Text(value.toStringAsFixed(value < 10 ? 1 : 0)),
          ],
        ),
        Slider(
          min: min,
          max: max,
          value: value.clamp(min, max),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
