import 'package:flutter/material.dart';
import 'package:foundation_domain/domain.dart';

import '../../../l10n/app_localizations.dart';

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
    final l10n = context.l10n;
    return DropdownButton<LibrarySortMode>(
      value: value,
      isDense: true,
      itemHeight: kMinInteractiveDimension,
      menuMaxHeight: 260,
      onChanged: (next) {
        if (next != null) {
          onChanged(next);
        }
      },
      items: [
        DropdownMenuItem(
          value: LibrarySortMode.recentRead,
          child: Text(l10n.sortByRecentRead),
        ),
        DropdownMenuItem(
          value: LibrarySortMode.importedAt,
          child: Text(l10n.sortByImportedAt),
        ),
        DropdownMenuItem(
          value: LibrarySortMode.name,
          child: Text(l10n.sortByName),
        ),
      ],
    );
  }
}
