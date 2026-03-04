import 'package:flutter/material.dart';

import '../../../../core/models/ygopro_card.dart';
import '../../domain/daily_slot_rule.dart';
import '../slot_ui/slot_ui_helpers.dart';

class SlotResultDialog extends StatelessWidget {
  final int hits;
  final int targets;
  final String title;
  final String message;
  final DailySlotRule rule;
  final List<YgoCard> cards;
  final bool isBossJackpot;

  const SlotResultDialog({
    super.key,
    required this.hits,
    required this.targets,
    required this.title,
    required this.message,
    required this.rule,
    required this.cards,
    this.isBossJackpot = false,
  });

  static const _kGold = Color(0xFFFFD700);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isJackpot = hits >= 3;

    IconData icon;
    String badge;

    if (isBossJackpot) {
      icon = Icons.workspace_premium;
      badge = 'BOSS JACKPOT';
    } else if (isJackpot) {
      icon = Icons.emoji_events;
      badge = 'JACKPOT';
    } else if (hits == 2) {
      icon = Icons.local_fire_department;
      badge = 'NICE';
    } else {
      icon = Icons.auto_awesome;
      badge = 'GOOD';
    }

    final iconColor = isBossJackpot
        ? _kGold
        : isJackpot
        ? _kGold
        : theme.colorScheme.primary;

    final badgeDecoration = isBossJackpot
        ? BoxDecoration(
            color: _kGold.withAlpha(60),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: _kGold, width: 1.5),
          )
        : isJackpot
        ? BoxDecoration(
            color: _kGold.withAlpha(32),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: _kGold.withAlpha(180)),
          )
        : BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: theme.dividerColor),
          );

    final badgeTextColor = isJackpot
        ? const Color(0xFFB8860B)
        : theme.colorScheme.onSurface;

    return AlertDialog(
      backgroundColor: isBossJackpot ? const Color(0xFF1A1000) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: isBossJackpot
            ? const BorderSide(color: _kGold, width: 3)
            : isJackpot
            ? const BorderSide(color: _kGold, width: 2)
            : BorderSide.none,
      ),
      titlePadding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
      contentPadding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
      actionsPadding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      title: Row(
        children: [
          Icon(icon, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: isBossJackpot ? _kGold : null,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: badgeDecoration,
            child: Text(
              '$badge  •  $hits / $targets',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: badgeTextColor,
              ),
            ),
          ),
          if (isBossJackpot) ...[
            const SizedBox(height: 6),
            Text(
              '전설의 잭팟 달성!',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.amberAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isBossJackpot
                  ? Colors.white70
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 160),
            child: SingleChildScrollView(
              child: Column(
                children: List.generate(rule.targets.length, (i) {
                  final SlotTarget t = rule.targets[i];
                  final ok = anyMatchTarget(cards: cards, t: t);

                  final isExact = t.cardId != null;
                  final label = isExact
                      ? (t.cardName ?? '카드 #${t.cardId}')
                      : prettyCategory(t.category ?? '');

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(
                          ok ? Icons.check_circle : Icons.cancel,
                          size: 18,
                          color: ok
                              ? (isBossJackpot || isJackpot ? _kGold : theme.colorScheme.primary)
                              : theme.colorScheme.error.withAlpha(180),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: isBossJackpot
              ? TextButton.styleFrom(foregroundColor: _kGold)
              : null,
          child: const Text('확인'),
        ),
      ],
    );
  }
}
