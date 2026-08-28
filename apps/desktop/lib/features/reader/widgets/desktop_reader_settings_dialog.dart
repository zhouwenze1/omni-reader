import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:foundation_domain/domain.dart';

import '../../../l10n/app_localizations.dart';

class DesktopReaderSettingsDialog extends StatefulWidget {
  const DesktopReaderSettingsDialog({
    super.key,
    required this.initialSettings,
    required this.onCommit,
  });

  final ReaderSettings initialSettings;
  final ValueChanged<ReaderSettings> onCommit;

  @override
  State<DesktopReaderSettingsDialog> createState() =>
      _DesktopReaderSettingsDialogState();
}

class _DesktopReaderSettingsDialogState
    extends State<DesktopReaderSettingsDialog> {
  late ReaderSettings _draft;

  @override
  void initState() {
    super.initState();
    _draft = widget.initialSettings;
  }

  void _updateDraft(ReaderSettings next) {
    setState(() {
      _draft = next;
    });
  }

  void _commitDraft() {
    widget.onCommit(_draft);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final viewport = MediaQuery.sizeOf(context);
    final horizontalInset = math.min(24.0, viewport.width * 0.05);
    final verticalInset = math.min(18.0, viewport.height * 0.05);
    final dialogWidth = math.min(
      460.0,
      math.max(0.0, viewport.width - horizontalInset * 2),
    );
    final dialogHeight = math.min(
      720.0,
      math.max(0.0, viewport.height - verticalInset * 2),
    );

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: horizontalInset,
        vertical: verticalInset,
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: SizedBox(
        width: math.min(460.0, dialogWidth),
        height: dialogHeight,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.readerSettings,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.close,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(right: 8, bottom: 8),
                  children: [
                    _slider(
                      title: l10n.fontSize,
                      value: _draft.fontSize,
                      valueLabel: _draft.fontSize.toStringAsFixed(0),
                      min: 12,
                      max: 42,
                      onChanged: (value) => _updateDraft(
                        _draft.copyWith(fontSize: value),
                      ),
                      onChangeEnd: (_) => _commitDraft(),
                    ),
                    _slider(
                      title: l10n.lineHeight,
                      value: _draft.lineHeight,
                      valueLabel: _draft.lineHeight.toStringAsFixed(2),
                      min: 1.1,
                      max: 2.4,
                      onChanged: (value) => _updateDraft(
                        _draft.copyWith(lineHeight: value),
                      ),
                      onChangeEnd: (_) => _commitDraft(),
                    ),
                    _slider(
                      title: l10n.pageGap,
                      value: _draft.pageGap,
                      valueLabel: _draft.pageGap.toStringAsFixed(0),
                      min: 0,
                      max: 80,
                      onChanged: (value) => _updateDraft(
                        _draft.copyWith(pageGap: value),
                      ),
                      onChangeEnd: (_) => _commitDraft(),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: _draft.layoutMode,
                      isExpanded: true,
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
                        if (value == null) return;
                        _updateDraft(_draft.copyWith(layoutMode: value));
                        _commitDraft();
                      },
                    ),
                    const SizedBox(height: 8),
                    _slider(
                      title: l10n.horizontalPadding,
                      value: _draft.paddingHorizontal,
                      valueLabel: _draft.paddingHorizontal.toStringAsFixed(0),
                      min: 0,
                      max: 100,
                      onChanged: (value) => _updateDraft(
                        _draft.copyWith(paddingHorizontal: value),
                      ),
                      onChangeEnd: (_) => _commitDraft(),
                    ),
                    _slider(
                      title: l10n.verticalPadding,
                      value: _draft.paddingVertical,
                      valueLabel: _draft.paddingVertical.toStringAsFixed(0),
                      min: 0,
                      max: 80,
                      onChanged: (value) => _updateDraft(
                        _draft.copyWith(paddingVertical: value),
                      ),
                      onChangeEnd: (_) => _commitDraft(),
                    ),
                    SwitchListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.enableTextIndent),
                      value: _draft.textIndentEnabled,
                      onChanged: (value) {
                        _updateDraft(
                          _draft.copyWith(textIndentEnabled: value),
                        );
                        _commitDraft();
                      },
                    ),
                    _slider(
                      title: l10n.indentSizeEm,
                      value: _draft.textIndentEm,
                      valueLabel: _draft.textIndentEm.toStringAsFixed(1),
                      min: 0,
                      max: 4,
                      onChanged: (value) => _updateDraft(
                        _draft.copyWith(textIndentEm: value),
                      ),
                      onChangeEnd: (_) => _commitDraft(),
                    ),
                    SwitchListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.skipFirstParagraphIndent),
                      value: _draft.textIndentSkipFirstParagraph,
                      onChanged: (value) {
                        _updateDraft(
                          _draft.copyWith(
                            textIndentSkipFirstParagraph: value,
                          ),
                        );
                        _commitDraft();
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.close),
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
    required String valueLabel,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
    required ValueChanged<double> onChangeEnd,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(title)),
            Text(valueLabel),
          ],
        ),
        Slider(
          min: min,
          max: max,
          value: value.clamp(min, max),
          onChanged: onChanged,
          onChangeEnd: onChangeEnd,
        ),
      ],
    );
  }
}
