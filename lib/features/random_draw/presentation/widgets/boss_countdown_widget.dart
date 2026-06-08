import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../core/app_colors.dart';
import '../../domain/daily_slot_rule.dart';

class BossCountdownWidget extends StatelessWidget {
  final int count;

  const BossCountdownWidget({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateTime.now();
    final todayKind = _kindFor(today, count);

    if (todayKind == DayKind.boss) {
      return _chip(
        theme,
        '👑 오늘이 보스데이!',
        AppColors.gold.withAlpha(60),
        AppColors.gold,
        AppColors.goldDark,
      );
    }

    final days = _daysUntilBoss(today, count);
    if (days <= 0) return const SizedBox.shrink();

    final label = days == 1 ? '내일이 보스데이!' : '보스데이까지 $days일 후';

    return _chip(
      theme,
      '👑 $label',
      theme.colorScheme.surfaceContainerHighest,
      theme.dividerColor,
      theme.colorScheme.onSurfaceVariant,
    );
  }

  Widget _chip(ThemeData theme, String text, Color bg, Color border, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border.withAlpha(180)),
      ),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  DayKind _kindFor(DateTime date, int count) {
    final d = DateTime(date.year, date.month, date.day);
    final seed = (d.year * 10000 + d.month * 100 + d.day) * 10 + (count % 10);
    final r = Random(seed);
    return pickTodayKind(count: count, r: r);
  }

  int _daysUntilBoss(DateTime today, int count) {
    for (int i = 1; i <= 30; i++) {
      final future = today.add(Duration(days: i));
      if (_kindFor(future, count) == DayKind.boss) return i;
    }
    return -1;
  }
}
