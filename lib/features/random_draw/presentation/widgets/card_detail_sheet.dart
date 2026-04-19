import 'package:flutter/material.dart';
import '../../../../../core/models/ygopro_card.dart';
import '../../../../../core/widgets/app_network_image.dart';
import '../../../../../core/widgets/ygo_card_back.dart';

class CardDetailSheet extends StatefulWidget {
  final YgoCard card;
  final bool isFavorite;
  final Future<void> Function() onToggleFavorite;
  final VoidCallback onShare;

  const CardDetailSheet({
    super.key,
    required this.card,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.onShare,
  });

  @override
  State<CardDetailSheet> createState() => _CardDetailSheetState();
}

class _CardDetailSheetState extends State<CardDetailSheet> {
  late bool _fav;

  @override
  void initState() {
    super.initState();
    _fav = widget.isFavorite;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final card = widget.card;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: AppNetworkImage(
                    card.imageUrl,
                    width: 80,
                    height: 116,
                    fit: BoxFit.cover,
                    fallback: (_) => const YgoCardBack(label: 'YGO'),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(card.name,
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      if (card.attribute != null) _InfoRow(label: '속성', value: card.attribute!),
                      if (card.race != null) _InfoRow(label: '종족', value: card.race!),
                      if (card.level != null) _InfoRow(label: '레벨', value: '${card.level}'),
                      if (card.atk != null || card.def != null)
                        _InfoRow(label: 'ATK/DEF', value: '${card.atk ?? "-"} / ${card.def ?? "-"}'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (card.desc.isNotEmpty)
              Text(
                card.desc,
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant),
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await widget.onToggleFavorite();
                      if (mounted) setState(() => _fav = !_fav);
                    },
                    icon: Icon(_fav ? Icons.bookmark : Icons.bookmark_border, size: 18),
                    label: Text(_fav ? '즐겨찾기 해제' : '즐겨찾기'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onShare();
                    },
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text('결과 공유'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          Text(value, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
