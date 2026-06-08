import 'package:flutter/material.dart';

import '../../../../core/app_colors.dart';
import '../../domain/target_pity.dart';

class BatchSummaryDialog extends StatelessWidget {
  final int total;
  final Map<int, int> hist;
  final int streak;
  final int best;
  final BatchBetOutcome bet;

  const BatchSummaryDialog({
    super.key,
    required this.total,
    required this.hist,
    required this.streak,
    required this.best,
    required this.bet,
  });

  static Future<void> show(
    BuildContext context, {
    required int total,
    required Map<int, int> hist,
    required int streak,
    required int best,
    required BatchBetOutcome bet,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (ctx, a1, a2) => BatchSummaryDialog(
        total: total,
        hist: hist,
        streak: streak,
        best: best,
        bet: bet,
      ),
      transitionBuilder: (ctx, animation, _, child) {
        final scale = CurvedAnimation(parent: animation, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.75, end: 1.0).animate(scale),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final zero = hist[0] ?? 0;
    final one = hist[1] ?? 0;
    final two = hist[2] ?? 0;
    final three = hist[3] ?? 0;

    final jackpotRate = total == 0 ? 0.0 : (three / total) * 100.0;
    final hitRate = total == 0 ? 0.0 : ((total - zero) / total) * 100.0;
    final hasJackpot = three > 0;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: hasJackpot
            ? const BorderSide(color: AppColors.gold, width: 2)
            : BorderSide.none,
      ),
      title: Text('🔁 연속 뽑기 결과',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('총 $total회',
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          _ResultBar(label: '0개 적중', count: zero, total: total,
              color: theme.colorScheme.onSurfaceVariant.withAlpha(100)),
          const SizedBox(height: 6),
          _ResultBar(label: '1개 적중', count: one, total: total,
              color: theme.colorScheme.secondary),
          const SizedBox(height: 6),
          _ResultBar(label: '2개 적중', count: two, total: total,
              color: theme.colorScheme.tertiary),
          const SizedBox(height: 6),
          _ResultBar(label: '3개(잭팟)', count: three, total: total,
              color: hasJackpot ? AppColors.gold : theme.colorScheme.primary),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: hasJackpot
                  ? AppColors.gold.withAlpha(20)
                  : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasJackpot
                    ? AppColors.gold.withAlpha(160)
                    : theme.dividerColor,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🎰 잭팟률: ${jackpotRate.toStringAsFixed(1)}%',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: hasJackpot ? AppColors.goldDark : null,
                  ),
                ),
                const SizedBox(height: 4),
                Text('✨ (참고) 1개 이상 적중률: ${hitRate.toStringAsFixed(1)}%',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: bet.won
                  ? AppColors.gold.withAlpha(28)
                  : theme.colorScheme.errorContainer.withAlpha(70),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: bet.won
                    ? AppColors.gold.withAlpha(140)
                    : theme.colorScheme.error.withAlpha(120),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bet.won
                      ? '🎉 베팅 성공! (${bet.betAmount}P 베팅)'
                      : '💸 베팅 실패... (${bet.betAmount}P 베팅)',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: bet.won ? AppColors.goldDark : theme.colorScheme.error,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '🎯 천장 포인트: ${bet.pointsBefore}P → ${bet.pointsAfter}P'
                  '${bet.pointsDoubled ? " (2배 적립!)" : ""}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                if (bet.won && bet.bonusCardCount > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    '🎁 보너스 카드 ${bet.bonusCardCount}장 획득!',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.goldDark,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (hasJackpot && streak > 0) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.gold.withAlpha(28),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.gold.withAlpha(140)),
              ),
              child: Text(
                '🔥 $streak일 연속 잭팟 달성 중!${best > 1 ? "  최고 $best일" : ""}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppColors.goldDark,
                ),
              ),
            ),
          ],
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

class _ResultBar extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final Color color;

  const _ResultBar({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio = total == 0 ? 0.0 : (count / total).clamp(0.0, 1.0);
    return Row(
      children: [
        SizedBox(width: 72, child: Text(label, style: theme.textTheme.bodySmall)),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 10,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 28,
          child: Text(
            '$count',
            textAlign: TextAlign.end,
            style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}
