import 'dart:math';
import '../../../core/api_client.dart';
import '../../../core/models/ygopro_card.dart';
import '../domain/draw_filter.dart';

class RandomDrawController {
  final YgoApiClient apiClient;
  final _random = Random();

  RandomDrawController(this.apiClient);

  Future<List<YgoCard>> generateDraw(DrawFilter filter) async {
    final data = await apiClient.fetchCards(filter.toApiParams());
    final cards = data.map((e) => YgoCard.fromJson(e as Map<String, dynamic>)).toList();

    cards.shuffle(_random);

    final count = filter.count.clamp(1, cards.length);
    return cards.take(count).toList();
  }
}