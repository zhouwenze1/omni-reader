class BookContentBlock {
  const BookContentBlock({
    required this.href,
    required this.role,
    required this.text,
    this.locations,
    this.locator,
  });

  final String href;
  final String role;
  final String text;
  final Map<String, Object?>? locations;
  final Map<String, Object?>? locator;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'href': href,
      'role': role,
      'text': text,
      if (locations != null && locations!.isNotEmpty) 'locations': locations,
      if (locator != null && locator!.isNotEmpty) 'locator': locator,
    };
  }
}

class BookContentDocument {
  const BookContentDocument({required this.total, required this.blocks});

  final int total;
  final List<BookContentBlock> blocks;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'total': total,
      'blocks': blocks.map((entry) => entry.toJson()).toList(),
    };
  }
}
