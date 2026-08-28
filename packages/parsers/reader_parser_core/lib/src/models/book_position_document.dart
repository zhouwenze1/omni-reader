class BookPositionEntry {
  const BookPositionEntry({
    required this.href,
    required this.mediaType,
    required this.locations,
  });

  final String href;
  final String mediaType;
  final Map<String, Object?> locations;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'href': href,
      'type': mediaType,
      'locations': locations,
    };
  }
}

class BookPositionDocument {
  const BookPositionDocument({
    required this.total,
    required this.positions,
  });

  final int total;
  final List<BookPositionEntry> positions;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'total': total,
      'positions': positions.map((entry) => entry.toJson()).toList(),
    };
  }
}

