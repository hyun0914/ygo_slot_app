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

  const SlotResultDialog({
    super.key,
    required this.hits,
    required this.targets,
    required this.title,
    required this.message,
    required this.rule,
    required this.cards,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    IconData icon;
    String badge;

    if (hits >= 3) {
      icon = Icons.emoji_events;
      badge = 'JACKPOT';
    } else if (hits == 2) {
      icon = Icons.local_fire_department;
      badge = 'NICE';
    } else {
      icon = Icons.auto_awesome;
      badge = 'GOOD';
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      titlePadding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
      contentPadding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
      actionsPadding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      title: Row(
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
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
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Text(
              '$badge  •  $hits / $targets',
              style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
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
                          color: ok ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
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
          child: const Text('확인'),
        ),
      ],
    );
  }
}