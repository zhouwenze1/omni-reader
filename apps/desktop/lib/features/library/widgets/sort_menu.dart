import 'package:flutter/material.dart';
import 'package:foundation_domain/domain.dart';

class SortMenu extends StatelessWidget {
  const SortMenu({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final LibrarySortMode value;
  final ValueChanged<LibrarySortMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButton<LibrarySortMode>(
      value: value,
      onChanged: (next) {
        if (next != null) {
          onChanged(next);
        }
      },
      items: const [
        DropdownMenuItem(
          value: LibrarySortMode.recentRead,
          child: Text('最近阅读'),
        ),
        DropdownMenuItem(
          value: LibrarySortMode.importedAt,
          child: Text('最近导入'),
        ),
        DropdownMenuItem(
          value: LibrarySortMode.name,
          child: Text('名称 A-Z'),
        ),
      ],
    );
  }
}
