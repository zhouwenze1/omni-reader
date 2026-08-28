import 'package:flutter/material.dart';

class DropdownTile<T> extends StatelessWidget {
  const DropdownTile({
    super.key,
    required this.title,
    required this.value,
    required this.items,
    required this.onChanged,
    this.leading,
  });

  final String title;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: leading,
      title: Text(title),
      trailing: DropdownButton<T>(
        value: value,
        items: items,
        onChanged: onChanged,
      ),
    );
  }
}
