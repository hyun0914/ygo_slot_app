import 'package:flutter/material.dart';

import '../../../../core/app_colors.dart';
import '../../application/play_log_store.dart';

class StreakCalendarWidget extends StatefulWidget {
  const StreakCalendarWidget({super.key});

  @override
  State<StreakCalendarWidget> createState() => _StreakCalendarWidgetState();
}

class _StreakCalendarWidgetState extends State<StreakCalendarWidget> {
  List<String> _playDates = [];
  List<String> _jackpotDates = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await PlayLogStore.load();
    if (!mounted) return;
    setState(() {
      _playDates = data.playDates;
      _jackpotDates = data.jackpotDates;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();
    if (_playDates.isEmpty && _jackpotDates.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final today = DateTime.now();

    // Show last 35 days (5 rows of 7)
    const totalDays = 35;
    final days = List.generate(totalDays, (i) {
      return today.subtract(Duration(days: totalDays - 1 - i));
    });

    // Weekday headers
    const weekdays = ['일', '월', '화', '수', '목', '금', '토'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
          child: Text(
            '뽑기 달력 (최근 5주)',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: [
              // Weekday headers
              Row(
                children: List.generate(7, (i) => Expanded(
                  child: Center(
                    child: Text(
                      weekdays[i],
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant.withAlpha(160),
                        fontSize: 10,
                      ),
                    ),
                  ),
                )),
              ),
              const SizedBox(height: 4),
              // Calendar grid
              for (int row = 0; row < 5; row++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    children: List.generate(7, (col) {
                      final idx = row * 7 + col;
                      final day = days[idx];
                      return Expanded(child: _DayCell(
                        day: day,
                        playDates: _playDates,
                        jackpotDates: _jackpotDates,
                      ));
                    }),
                  ),
                ),
            ],
          ),
        ),
        // Legend
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
          child: Row(
            children: [
              _LegendDot(color: AppColors.gold.withAlpha(220), label: '잭팟'),
              const SizedBox(width: 12),
              _LegendDot(color: Colors.green.withAlpha(180), label: '플레이'),
              const SizedBox(width: 12),
              _LegendDot(
                color: theme.colorScheme.surfaceContainerHighest,
                label: '미플레이',
                border: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  final DateTime day;
  final List<String> playDates;
  final List<String> jackpotDates;

  const _DayCell({
    required this.day,
    required this.playDates,
    required this.jackpotDates,
  });

  String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final key = _key(day);
    final isJackpot = jackpotDates.contains(key);
    final isPlayed = playDates.contains(key);
    final isToday = key == _key(DateTime.now());

    Color bgColor;
    Color textColor;
    Border? border;

    if (isJackpot) {
      bgColor = AppColors.gold.withAlpha(200);
      textColor = Colors.black87;
    } else if (isPlayed) {
      bgColor = Colors.green.withAlpha(160);
      textColor = Colors.white;
    } else {
      bgColor = theme.colorScheme.surfaceContainerHighest.withAlpha(80);
      textColor = theme.colorScheme.onSurfaceVariant.withAlpha(120);
    }

    if (isToday) {
      border = Border.all(
        color: theme.colorScheme.primary,
        width: 1.5,
      );
    }

    return AspectRatio(
      aspectRatio: 1,
      child: Padding(
        padding: const EdgeInsets.all(1.5),
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(4),
            border: border,
          ),
          child: Center(
            child: Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                color: textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final bool border;

  const _LegendDot({required this.color, required this.label, this.border = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
            border: border
                ? Border.all(color: theme.colorScheme.outline.withAlpha(100))
                : null,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withAlpha(180),
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}
