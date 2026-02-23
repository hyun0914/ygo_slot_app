import 'package:flutter/material.dart';

import '../../domain/daily_slot_rule.dart';
import '../slot_ui/slot_ui_helpers.dart';

import 'slot_card_cell.dart';

class SlotHeader extends StatelessWidget {
  final DailySlotRule? rule;
  final int count;
  final void Function(SlotTarget t)? onTapExactTarget;

  const SlotHeader({
    super.key,
    required this.rule,
    required this.count,
    this.onTapExactTarget,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (rule == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Row(
          children: [
            const Icon(Icons.casino, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '오늘의 슬롯 타겟 준비 중… (첫 뽑기 후 고정)',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          // DAILY xN
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  blurRadius: 12,
                  spreadRadius: 0,
                  color: theme.colorScheme.primary.withAlpha(45),
                ),
              ],
            ),
            child: Text(
              'DAILY x$count',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.6,
              ),
            ),
          ),

          // 오늘 kind 칩
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: dayKindChipBg(theme, rule!.kind),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: dayKindChipBorder(theme, rule!.kind)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  dayKindIcon(rule!.kind),
                  size: 14,
                  color: dayKindChipFg(theme, rule!.kind),
                ),
                const SizedBox(width: 6),
                Text(
                  dayKindLabel(rule!.kind),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: dayKindChipFg(theme, rule!.kind),
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // 3칸 슬롯
          Expanded(
            child: Row(
              children: List.generate(3, (i) {
                final SlotTarget t = rule!.targets[i];

                final isExact =
                    t.cardId != null && (t.imageUrl ?? '').trim().isNotEmpty;

                final title = isExact
                    ? (t.cardName ?? '카드 #${t.cardId}')
                    : prettyCategory(t.category ?? '');

                final bgUrl = isExact ? t.imageUrl : null;

                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: i == 0 ? 0 : 8),
                    child: SlotCardCell(
                      title: title,
                      imageUrl: bgUrl,
                      isExact: isExact,
                      difficulty: isExact
                          ? SlotDifficulty.hard
                          : difficultyForCategoryKey(t.category ?? ''),
                      onTapPreview: isExact ? () => onTapExactTarget?.call(t) : null,
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}