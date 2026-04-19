import 'package:flutter/material.dart';
import '../../../../../core/app_constants.dart';
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
    final size = MediaQuery.sizeOf(context);
    final cardWidth = (size.width * 0.30).clamp(90.0, 140.0);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 카드 이미지
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: cardWidth,
                    child: AspectRatio(
                      aspectRatio: AppConstants.ygoCardAspectRatio,
                      child: AppNetworkImage(
                        card.imageUrl,
                        fit: BoxFit.contain,
                        fallback: (_) => const YgoCardBack(label: 'YGO'),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // 카드 정보
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        card.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (card.attribute != null || card.race != null)
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (card.attribute != null)
                              _Chip(card.attribute!.toUpperCase()),
                            if (card.race != null) _Chip(card.race!),
                            if (card.level != null) _Chip('Lv ${card.level}'),
                          ],
                        ),
                      if (card.atk != null || card.def != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _StatBadge(
                              label: 'ATK',
                              value: '${card.atk ?? "?"}',
                              color: theme.colorScheme.error,
                            ),
                            const SizedBox(width: 8),
                            _StatBadge(
                              label: 'DEF',
                              value: '${card.def ?? "?"}',
                              color: theme.colorScheme.secondary,
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (card.desc.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  card.desc,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () async {
                      await widget.onToggleFavorite();
                      if (mounted) setState(() => _fav = !_fav);
                    },
                    icon: Icon(
                      _fav ? Icons.bookmark : Icons.bookmark_border,
                      size: 18,
                    ),
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

class _Chip extends StatelessWidget {
  final String label;
  const _Chip(this.label);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatBadge({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label ',
          style: theme.textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}
