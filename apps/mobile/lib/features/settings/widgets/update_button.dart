import 'package:flutter/material.dart';

class UpdateButton extends StatelessWidget {
  const UpdateButton({
    super.key,
    required this.onPressed,
    this.label = '检查更新',
  });

  final VoidCallback? onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.system_update_alt),
      label: Text(label),
    );
  }
}
