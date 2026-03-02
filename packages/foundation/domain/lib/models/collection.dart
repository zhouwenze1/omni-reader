class Collection {
  const Collection({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Collection.fromJson(Map<String, dynamic> json) {
    return Collection(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (json['createdAt'] as num).toInt(),
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (json['updatedAt'] as num).toInt(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }
}

class CollectionItem {
  const CollectionItem({
    required this.collectionId,
    required this.bookUid,
    required this.addedAt,
  });

  final int collectionId;
  final String bookUid;
  final DateTime addedAt;

  factory CollectionItem.fromJson(Map<String, dynamic> json) {
    return CollectionItem(
      collectionId: (json['collectionId'] as num).toInt(),
      bookUid: json['bookUid'] as String,
      addedAt: DateTime.fromMillisecondsSinceEpoch(
        (json['addedAt'] as num).toInt(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'collectionId': collectionId,
      'bookUid': bookUid,
      'addedAt': addedAt.millisecondsSinceEpoch,
    };
  }
}
