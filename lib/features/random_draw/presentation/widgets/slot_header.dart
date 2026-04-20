import 'package:flutter/material.dart';

import '../../../../core/app_strings.dart';
import '../../domain/daily_slot_rule.dart';
import '../slot_ui/slot_ui_helpers.dart';

import 'skeleton.dart';
import 'slot_card_cell.dart';

class SlotHeader extends StatelessWidget {
  final DailySlotRule? rule;
  final int count;
  final void Function(SlotTarget t)? onTapExactTarget;
  final bool compact;

  const SlotHeader({
    super.key,
    required this.rule,
    required this.count,
    this.onTapExactTarget,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: rule == null
          ? _buildSkeleton(theme)
          : _buildLoaded(theme),
    );
  }

  Widget _buildSkeleton(ThemeData theme) {
    final vp = compact ? 6.0 : 10.0;
    return Semantics(
      key: const ValueKey('header_loading'),
      label: AppStrings.headerLoading,
      child: Container(
        padding: EdgeInsets.fromLTRB(12, vp, 12, vp),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Row(
          children: [
            // DAILY xN 배지 shimmer
            ShimmerBox(
              width: 72,
              height: compact ? 22 : 28,
              borderRadius: BorderRadius.circular(999),
            ),
            const SizedBox(width: 8),
            ShimmerBox(
              width: 52,
              height: compact ? 22 : 28,
              borderRadius: BorderRadius.circular(999),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Row(
                children: List.generate(3, (i) {
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(left: i == 0 ? 0 : 8),
                      child: ShimmerBox(
                        height: compact ? 46 : 62,
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoaded(ThemeData theme) {
    final vp = compact ? 6.0 : 10.0;
    return Container(
      key: ValueKey(rule!.kind),
      padding: EdgeInsets.fromLTRB(12, vp, 12, vp),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 380;
          final badges = Row(
            mainAxisSize: MainAxisSize.min,
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
              const SizedBox(width: 8),
              // 오늘 kind 칩
              Semantics(
                label: '오늘의 모드: ${dayKindLabel(rule!.kind)}',
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: dayKindChipBg(theme, rule!.kind),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: dayKindChipBorder(theme, rule!.kind)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(dayKindIcon(rule!.kind), size: 14,
                          color: dayKindChipFg(theme, rule!.kind)),
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
              ),
            ],
          );

          final slots = Row(
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
                    compact: compact,
                    difficulty: isExact
                        ? SlotDifficulty.hard
                        : difficultyForCategoryKey(t.category ?? ''),
                    onTapPreview: isExact ? () => onTapExactTarget?.call(t) : null,
                    heroTag: isExact ? 'slot_card_${t.cardId}' : null,
                  ),
                ),
              );
            }),
          );

          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                badges,
                const SizedBox(height: 8),
                slots,
              ],
            );
          }

          return Row(
            children: [
              badges,
              const SizedBox(width: 10),
              Expanded(child: slots),
            ],
          );
        },
      ),
    );
  }
}
