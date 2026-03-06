import 'package:flutter/material.dart';
import 'package:foundation_domain/domain.dart';

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
                '阅读设置',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              _slider(
                context,
                title: '字体大小',
                value: settings.fontSize,
                min: 12,
                max: 42,
                onChanged: (value) =>
                    onChanged(settings.copyWith(fontSize: value)),
              ),
              _slider(
                context,
                title: '行高',
                value: settings.lineHeight,
                min: 1.1,
                max: 2.4,
                onChanged: (value) =>
                    onChanged(settings.copyWith(lineHeight: value)),
              ),
              _slider(
                context,
                title: '页间距',
                value: settings.pageGap,
                min: 0,
                max: 80,
                onChanged: (value) =>
                    onChanged(settings.copyWith(pageGap: value)),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: settings.rendererTheme,
                decoration: const InputDecoration(labelText: '主题'),
                items: const [
                  DropdownMenuItem(value: 'day', child: Text('白天')),
                  DropdownMenuItem(value: 'night', child: Text('夜间')),
                  DropdownMenuItem(value: 'sepia', child: Text('护眼')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    onChanged(settings.copyWith(rendererTheme: value));
                  }
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('首行缩进'),
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

  Widget _slider(
    BuildContext context, {
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
