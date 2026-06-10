import 'dart:math';

const Map<String, String> frameTypeToKr = {
  'normal': '일반',
  'effect': '효과',
  'ritual': '의식',
  'fusion': '융합',
  'synchro': '싱크로',
  'xyz': '엑시즈',
  'link': '링크',
  'pendulum': '펜듈럼',
  'normal_pendulum': '일반 펜듈럼',
  'effect_pendulum': '효과 펜듈럼',
  'ritual_pendulum': '의식 펜듈럼',
  'fusion_pendulum': '융합 펜듈럼',
  'synchro_pendulum': '싱크로 펜듈럼',
  'xyz_pendulum': '엑시즈 펜듈럼',
  'ritual_effect': '의식 효과',
};

const Map<String, String> attributeToKr = {
  'DARK': '어둠',
  'LIGHT': '빛',
  'FIRE': '화염',
  'WATER': '물',
  'EARTH': '땅',
  'WIND': '바람',
  'DIVINE': '신',
};

const Map<String, String> raceToKr = {
  'Spellcaster': '마법사족',
  'Dragon': '드래곤족',
  'Zombie': '언데드족',
  'Warrior': '전사족',
  'Beast-Warrior': '야수전사족',
  'Beast': '야수족',
  'Winged Beast': '비행야수족',
  'Fiend': '악마족',
  'Fairy': '천사족',
  'Insect': '곤충족',
  'Dinosaur': '공룡족',
  'Reptile': '파충류족',
  'Fish': '어류족',
  'Sea Serpent': '해룡족',
  'Aqua': '물족',
  'Pyro': '화염족',
  'Thunder': '번개족',
  'Rock': '암석족',
  'Plant': '식물족',
  'Machine': '기계족',
  'Psychic': '사이킥족',
  'Divine-Beast': '환신야수족',
  'Wyrm': '환룡족',
  'Cyberse': '사이버스족',
  'Illusion': '환상마족',
};

const List<String> kHintKeys = [
  'monsterType',
  'attribute',
  'levelRankLink',
  'race',
  'atk',
  'def',
];

const Map<String, String> kHintLabels = {
  'monsterType': '종류',
  'attribute': '속성',
  'levelRankLink': '레벨/랭크/링크',
  'race': '종족',
  'atk': '공격력',
  'def': '수비력',
};

class DecoderCard {
  final int id;
  final String name;
  final String frameType;
  final String attribute;
  final int levelRankLink;
  final String race;
  final int? atk;
  final int? def;
  final String imageUrl;

  const DecoderCard({
    required this.id,
    required this.name,
    required this.frameType,
    required this.attribute,
    required this.levelRankLink,
    required this.race,
    this.atk,
    this.def,
    required this.imageUrl,
  });

  bool get isLink => frameType == 'link';
  bool get isXyz =>
      frameType == 'xyz' || frameType == 'xyz_pendulum';

  String get monsterTypeKr => frameTypeToKr[frameType] ?? frameType;
  String get attributeKr => attributeToKr[attribute] ?? attribute;
  String get raceKr => raceToKr[race] ?? race;
  String get atkDisplay => atk == null ? '?' : atk.toString();
  String get defDisplay => isLink ? '-' : (def == null ? '?' : def.toString());

  String get levelRankLinkDisplay {
    if (isLink) return '링크 $levelRankLink';
    if (isXyz) return '랭크 $levelRankLink';
    return '레벨 $levelRankLink';
  }

  String hintValue(String key) => switch (key) {
        'monsterType' => monsterTypeKr,
        'attribute' => attributeKr,
        'levelRankLink' => levelRankLink.toString(),
        'race' => raceKr,
        'atk' => atkDisplay,
        'def' => defDisplay,
        _ => '',
      };

  // 카드 ID 기반으로 힌트 공개 순서를 결정한다. 모든 유저가 동일한 순서를 봄.
  List<String> revealOrder() {
    final keys = List<String>.from(kHintKeys);
    keys.shuffle(Random(id));
    return keys;
  }

  factory DecoderCard.fromJson(Map<String, dynamic> json) {
    final images = (json['card_images'] as List?) ?? const [];
    final firstImage =
        images.isNotEmpty ? images.first as Map<String, dynamic> : const {};
    final rawUrl = (firstImage['image_url'] as String?)?.trim() ?? '';
    final imageUrl = rawUrl.replaceFirst('http://', 'https://');

    final frameType = ((json['frameType'] as String?) ?? '').toLowerCase();
    final isLink = frameType == 'link';

    final levelRankLink = isLink
        ? (json['linkval'] as num?)?.toInt() ?? 0
        : (json['level'] as num?)?.toInt() ?? 0;

    return DecoderCard(
      id: (json['id'] as num).toInt(),
      name: (json['name'] ?? '').toString(),
      frameType: frameType,
      attribute: ((json['attribute'] as String?) ?? '').toUpperCase(),
      levelRankLink: levelRankLink,
      race: (json['race'] as String?) ?? '',
      atk: (json['atk'] as num?)?.toInt(),
      def: isLink ? 0 : (json['def'] as num?)?.toInt(),
      imageUrl: imageUrl,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'frameType': frameType,
        'attribute': attribute,
        'levelRankLink': levelRankLink,
        'race': race,
        'atk': atk,
        'def': def,
        'imageUrl': imageUrl,
      };

  factory DecoderCard.fromCacheJson(Map<String, dynamic> json) {
    return DecoderCard(
      id: (json['id'] as num).toInt(),
      name: (json['name'] ?? '').toString(),
      frameType: (json['frameType'] ?? '').toString(),
      attribute: (json['attribute'] ?? '').toString(),
      levelRankLink: (json['levelRankLink'] as num?)?.toInt() ?? 0,
      race: (json['race'] ?? '').toString(),
      atk: (json['atk'] as num?)?.toInt(),
      def: (json['def'] as num?)?.toInt(),
      imageUrl: (json['imageUrl'] ?? '').toString(),
    );
  }
}
