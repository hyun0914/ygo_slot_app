import 'package:flutter/material.dart';

import '../../../../core/models/ygopro_card.dart';
import '../../application/weekly_challenge_store.dart';
import '../../domain/weekly_challenge.dart';

class WeeklyChallengeWidget extends StatefulWidget {
  /// Currently displayed drawn cards (null = no draw yet)
  final List<YgoCard>? cards;

  const WeeklyChallengeWidget({super.key, this.cards});

  @override
  State<WeeklyChallengeWidget> createState() => _WeeklyChallengeWidgetState();
}

class _WeeklyChallengeWidgetState extends State<WeeklyChallengeWidget> {
  late WeeklyChallengeDef _challenge;
  int _completionsThisWeek = 0;

  @override
  void initState() {
    super.initState();
    _challenge = pickWeeklyChallenge(now: DateTime.now());
    _loadCompletions();
  }

  Future<void> _loadCompletions() async {
    final n = await WeeklyChallengeStore.getCompletionsThisWeek();
    if (mounted) setState(() => _completionsThisWeek = n);
  }

  @override
  void didUpdateWidget(WeeklyChallengeWidget old) {
    super.didUpdateWidget(old);
    if (old.cards != widget.cards) _loadCompletions();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cards = widget.cards ?? [];
    final matched = _challenge.countMatches(cards);
    final required = _challenge.requiredCount;
    final done = matched >= required && cards.isNotEmpty;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: done
            ? Colors.green.withAlpha(40)
            : theme.colorScheme.surfaceContainerHighest.withAlpha(80),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: done
              ? Colors.green.withAlpha(160)
              : theme.dividerColor.withAlpha(120),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // Icon
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: done
                    ? Colors.green.withAlpha(80)
                    : theme.colorScheme.primaryContainer.withAlpha(120),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  done ? '✅' : '🎯',
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '위클리 챌린지',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                      if (_completionsThisWeek > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.amber.withAlpha(60),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '이번 주 $_completionsThisWeek회 달성',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 9,
                              color: Colors.amber.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    _challenge.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _challenge.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Progress
            if (cards.isNotEmpty)
              _ProgressCircle(current: matched, total: required, done: done),
          ],
        ),
      ),
    );
  }
}

class _ProgressCircle extends StatelessWidget {
  final int current;
  final int total;
  final bool done;

  const _ProgressCircle({required this.current, required this.total, required this.done});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = total == 0 ? 1.0 : (current / total).clamp(0.0, 1.0);

    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: progress,
            strokeWidth: 4,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(
              done ? Colors.green : theme.colorScheme.primary,
            ),
          ),
          Center(
            child: Text(
              done ? '✓' : '$current/$total',
              style: TextStyle(
                fontSize: done ? 14 : 10,
                fontWeight: FontWeight.bold,
                color: done ? Colors.green : theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
