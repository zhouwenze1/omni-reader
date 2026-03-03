import 'package:flutter/material.dart';

class LibraryFilterOption<T> {
  const LibraryFilterOption({
    required this.value,
    required this.label,
    this.leadingIcon,
  });

  final T value;
  final String label;
  final IconData? leadingIcon;
}

class LibraryFilterDropdown<T> extends StatelessWidget {
  const LibraryFilterDropdown({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.hintText,
  });

  final T? value;
  final List<LibraryFilterOption<T>> options;
  final ValueChanged<T?> onChanged;
  final String? hintText;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final colorScheme = Theme.of(context).colorScheme;

        return DropdownMenu<T>(
          key: ValueKey<Object?>(value),
          width: width,
          menuHeight: 240,
          enableFilter: options.length > 6,
          enableSearch: true,
          requestFocusOnTap: false,
          hintText: hintText,
          trailingIcon: const Icon(Icons.expand_more_rounded),
          selectedTrailingIcon: const Icon(Icons.expand_less_rounded),
          textStyle: Theme.of(context).textTheme.bodyLarge,
          inputDecorationTheme: InputDecorationTheme(
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            filled: true,
            fillColor: colorScheme.surfaceContainerHigh,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: colorScheme.outlineVariant),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: colorScheme.outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
            ),
          ),
          initialSelection: value,
          dropdownMenuEntries: options
              .map(
                (item) => DropdownMenuEntry<T>(
                  value: item.value,
                  label: item.label,
                  leadingIcon:
                      item.leadingIcon == null ? null : Icon(item.leadingIcon),
                ),
              )
              .toList(),
          onSelected: onChanged,
        );
      },
    );
  }
}
