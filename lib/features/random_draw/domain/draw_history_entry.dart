class DrawHistoryCard {
  final int id;
  final String name;
  final String imageUrl;

  DrawHistoryCard({
    required this.id,
    required this.name,
    required this.imageUrl,
  });

  factory DrawHistoryCard.fromJson(Map<String, dynamic> m) => DrawHistoryCard(
        id: (m['id'] as num).toInt(),
        name: m['name'] as String,
        imageUrl: (m['imageUrl'] as String?) ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'imageUrl': imageUrl,
      };
}

class DrawHistoryEntry {
  final String id;
  final DateTime timestamp;
  final int hits;
  final int mode;
  final List<DrawHistoryCard> cards;

  DrawHistoryEntry({
    required this.id,
    required this.timestamp,
    required this.hits,
    required this.mode,
    required this.cards,
  });

  factory DrawHistoryEntry.fromJson(Map<String, dynamic> m) => DrawHistoryEntry(
        id: m['id'] as String,
        timestamp: DateTime.parse(m['ts'] as String),
        hits: (m['hits'] as num).toInt(),
        mode: (m['mode'] as num).toInt(),
        cards: ((m['cards'] as List?) ?? [])
            .map((e) => DrawHistoryCard.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'ts': timestamp.toIso8601String(),
        'hits': hits,
        'mode': mode,
        'cards': cards.map((c) => c.toJson()).toList(),
      };
}
