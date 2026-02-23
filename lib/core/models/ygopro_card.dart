class YgoCard {
  final int id;
  final String name;
  final String type;
  final String desc;
  final int? atk;
  final int? def;
  final int? level;
  final String? race;
  final String? attribute;
  final String imageUrl;

  YgoCard({
    required this.id,
    required this.name,
    required this.type,
    required this.desc,
    this.atk,
    this.def,
    this.level,
    this.race,
    this.attribute,
    required this.imageUrl,
  });

  factory YgoCard.fromJson(Map<String, dynamic> json) {
    final images = (json['card_images'] as List?) ?? const [];
    final firstImage = images.isNotEmpty ? images.first as Map<String, dynamic> : const {};

    final rawUrl = (firstImage['image_url'] as String?)?.trim() ?? '';
    final imageUrl = rawUrl.replaceFirst('http://', 'https://');

    return YgoCard(
      id: (json['id'] as num).toInt(),
      name: (json['name'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      desc: (json['desc'] ?? '').toString(),
      atk: (json['atk'] as num?)?.toInt(),
      def: (json['def'] as num?)?.toInt(),
      level: (json['level'] as num?)?.toInt(),
      race: (json['race'] as String?)?.toString(),
      attribute: (json['attribute'] as String?)?.toString(),
      imageUrl: imageUrl,
    );
  }
}