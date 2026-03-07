import 'package:flutter/material.dart';
import 'package:foundation_domain/domain.dart';

import '../../../l10n/l10n.dart';

class ReaderSettingsPanel extends StatefulWidget {
  const ReaderSettingsPanel({
    super.key,
    required this.settings,
    required this.onChanged,
  });

  final ReaderSettings settings;
  final ValueChanged<ReaderSettings> onChanged;

  @override
  State<ReaderSettingsPanel> createState() => _ReaderSettingsPanelState();
}

class _ReaderSettingsPanelState extends State<ReaderSettingsPanel> {
  late ReaderSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = widget.settings;
  }

  @override
  void didUpdateWidget(covariant ReaderSettingsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings != widget.settings) {
      _settings = widget.settings;
    }
  }

  void _updateSettings(ReaderSettings next) {
    setState(() {
      _settings = next;
    });
    widget.onChanged(next);
  }

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
                value: _settings.fontSize,
                min: 12,
                max: 42,
                onChanged: (value) =>
                    _updateSettings(_settings.copyWith(fontSize: value)),
              ),
              _slider(
                title: l10n.lineHeight,
                value: _settings.lineHeight,
                min: 1.1,
                max: 2.4,
                onChanged: (value) =>
                    _updateSettings(_settings.copyWith(lineHeight: value)),
              ),
              _slider(
                title: l10n.pageGap,
                value: _settings.pageGap,
                min: 0,
                max: 80,
                onChanged: (value) =>
                    _updateSettings(_settings.copyWith(pageGap: value)),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                key: ValueKey('theme-${_settings.rendererTheme}'),
                initialValue: _settings.rendererTheme,
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
                    _updateSettings(_settings.copyWith(rendererTheme: value));
                  }
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey('layout-${_settings.layoutMode}'),
                initialValue: _settings.layoutMode,
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
                    _updateSettings(_settings.copyWith(layoutMode: value));
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
                value: _settings.textIndentEnabled,
                onChanged: (value) => _updateSettings(
                  _settings.copyWith(textIndentEnabled: value),
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
