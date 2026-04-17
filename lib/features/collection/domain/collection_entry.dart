class CollectionEntry {
  final int id;
  final String name;
  final String imageUrl;
  final String firstSeen;
  final int count;

  const CollectionEntry({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.firstSeen,
    required this.count,
  });

  CollectionEntry withCount(int newCount) => CollectionEntry(
        id: id,
        name: name,
        imageUrl: imageUrl,
        firstSeen: firstSeen,
        count: newCount,
      );

  factory CollectionEntry.fromJson(Map<String, dynamic> m) => CollectionEntry(
        id: (m['id'] as num).toInt(),
        name: m['name'] as String,
        imageUrl: (m['img'] as String?) ?? '',
        firstSeen: (m['fs'] as String?) ?? '',
        count: (m['n'] as num?)?.toInt() ?? 1,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'img': imageUrl,
        'fs': firstSeen,
        'n': count,
      };
}
