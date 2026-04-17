import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../features/collection/application/collection_store.dart';
import '../../../../features/level/application/level_store.dart';
import '../../../../features/level/domain/level_config.dart';
import '../../../../features/random_draw/application/draw_history_store.dart';
import '../../../../features/random_draw/application/draw_stats_store.dart';
import '../../../../features/random_draw/application/play_log_store.dart';
import '../../../../features/weekly_challenge/application/weekly_challenge_store.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  bool _loading = true;

  int _totalDraws = 0;
  int _totalJackpots = 0;
  int _bestStreak = 0;
  int _currentStreak = 0;
  int _xp = 0;
  int _collectionSize = 0;
  int _weeklyCompletions = 0;

  // From history (last 30)
  double _avgHits = 0;
  double _jackpotRate = 0;
  Map<int, int> _hitDist = {0: 0, 1: 0, 2: 0, 3: 0};

  // Attribute distribution from collection

  // Play log
  int _playDaysLast30 = 0;
  int _jackpotDaysLast30 = 0;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final prefs = await SharedPreferences.getInstance();

    // Streak
    int totalJackpots = 0, bestStreak = 0, currentStreak = 0;
    final rawStreak = prefs.getString('ygo_jackpot_streak_v1');
    if (rawStreak != null) {
      try {
        final m = jsonDecode(rawStreak) as Map<String, dynamic>;
        totalJackpots = (m['total'] as num?)?.toInt() ?? 0;
        bestStreak = (m['best'] as num?)?.toInt() ?? 0;
        final lastDate = (m['streak'] as num?)?.toInt() ?? 0;
        currentStreak = lastDate;
      } catch (_) {}
    }

    final totalDraws = await DrawStatsStore.getTotalDraws();
    final xp = await LevelStore.getTotalXp();
    final collection = await CollectionStore.loadAll();
    final history = await DrawHistoryStore.loadAll();
    final playLog = await PlayLogStore.load();
    final weeklyComp = await WeeklyChallengeStore.getCompletionsThisWeek();

    // Hit distribution from history
    final dist = <int, int>{0: 0, 1: 0, 2: 0, 3: 0};
    for (final e in history) {
      final hits = e.hits.clamp(0, 3);
      dist[hits] = (dist[hits] ?? 0) + 1;
    }
    final histTotal = history.length;
    final totalHits = history.fold(0, (s, e) => s + e.hits);
    final jackpots = dist[3] ?? 0;


    // Play log stats
    final today = DateTime.now();
    final cutoff30 = today.subtract(const Duration(days: 30));
    final cutoffStr =
        '${cutoff30.year}-${cutoff30.month.toString().padLeft(2, '0')}-${cutoff30.day.toString().padLeft(2, '0')}';
    final recentPlay =
        playLog.playDates.where((d) => d.compareTo(cutoffStr) >= 0).length;
    final recentJackpot =
        playLog.jackpotDates.where((d) => d.compareTo(cutoffStr) >= 0).length;

    if (!mounted) return;
    setState(() {
      _totalDraws = totalDraws;
      _totalJackpots = totalJackpots;
      _bestStreak = bestStreak;
      _currentStreak = currentStreak;
      _xp = xp;
      _collectionSize = collection.length;
      _weeklyCompletions = weeklyComp;
      _hitDist = dist;
      _avgHits = histTotal == 0 ? 0 : totalHits / histTotal;
      _jackpotRate = histTotal == 0 ? 0 : jackpots / histTotal * 100;
      _playDaysLast30 = recentPlay;
      _jackpotDaysLast30 = recentJackpot;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('통계 대시보드')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SectionTitle('📊 전체 현황'),
                const SizedBox(height: 8),
                _StatsGrid([
                  _StatCard('총 뽑기', '$_totalDraws회', Icons.casino, theme.colorScheme.primary),
                  _StatCard('누적 잭팟', '$_totalJackpots회', Icons.emoji_events, Colors.amber),
                  _StatCard('최고 연속', '$_bestStreak일', Icons.local_fire_department, Colors.orange),
                  _StatCard('현재 연속', '$_currentStreak일', Icons.whatshot, Colors.red),
                  _StatCard('수집 카드', '$_collectionSize종', Icons.style, Colors.green),
                  _StatCard('이번 주 챌린지', '$_weeklyCompletions회 달성', Icons.flag, Colors.purple),
                ]),
                const SizedBox(height: 20),
                _SectionTitle('⚡ 레벨 현황'),
                const SizedBox(height: 8),
                _LevelCard(xp: _xp),
                const SizedBox(height: 20),
                _SectionTitle('🎯 히트 분포 (최근 30회)'),
                const SizedBox(height: 8),
                _HitDistChart(dist: _hitDist, avgHits: _avgHits, jackpotRate: _jackpotRate),
                const SizedBox(height: 20),
                _SectionTitle('📅 최근 30일 플레이'),
                const SizedBox(height: 8),
                _PlayDaysCard(playDays: _playDaysLast30, jackpotDays: _jackpotDaysLast30),
              ],
            ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      );
}

class _StatsGrid extends StatelessWidget {
  final List<_StatCard> cards;
  const _StatsGrid(this.cards);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final cols = constraints.maxWidth > 500 ? 3 : 2;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: cards.map((c) {
          final w = (constraints.maxWidth - (cols - 1) * 10) / cols;
          return SizedBox(width: w, child: c);
        }).toList(),
      );
    });
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  final int xp;
  const _LevelCard({required this.xp});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final level = xpToLevel(xp);
    final title = levelTitle(level);
    final emoji = levelEmoji(level);
    final band = xpBand(xp);
    final toNext = xpToNextLevel(xp);
    final progress = level >= kMaxLevel
        ? 1.0
        : (xp - band.min) / (band.max - band.min).toDouble();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withAlpha(80),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lv.$level — $title',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      level < kMaxLevel ? '다음 레벨까지 ${toNext}XP (총 ${xp}XP)' : 'MAX 레벨! 총 ${xp}XP',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                level >= kMaxLevel ? Colors.amber : theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HitDistChart extends StatelessWidget {
  final Map<int, int> dist;
  final double avgHits;
  final double jackpotRate;

  const _HitDistChart({required this.dist, required this.avgHits, required this.jackpotRate});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = dist.values.fold(0, (a, b) => a + b);

    if (total == 0) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withAlpha(60),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '아직 뽑기 기록이 없습니다',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
      );
    }

    final barColors = [
      theme.colorScheme.onSurfaceVariant.withAlpha(120),
      theme.colorScheme.secondary,
      theme.colorScheme.tertiary,
      Colors.amber,
    ];
    final labels = ['0개 적중', '1개 적중', '2개 적중', '3개(잭팟)'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(60),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          for (int i = 0; i <= 3; i++) ...[
            _DistBar(
              label: labels[i],
              count: dist[i] ?? 0,
              total: total,
              color: barColors[i],
            ),
            if (i < 3) const SizedBox(height: 8),
          ],
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _MiniStat('평균 히트', avgHits.toStringAsFixed(2)),
              _MiniStat('잭팟율', '${jackpotRate.toStringAsFixed(1)}%'),
              _MiniStat('기록 수', '$total회'),
            ],
          ),
        ],
      ),
    );
  }
}

class _DistBar extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final Color color;

  const _DistBar({required this.label, required this.count, required this.total, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio = total == 0 ? 0.0 : (count / total).clamp(0.0, 1.0);
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(label, style: theme.textTheme.bodySmall),
        ),
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
            style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _PlayDaysCard extends StatelessWidget {
  final int playDays;
  final int jackpotDays;

  const _PlayDaysCard({required this.playDays, required this.jackpotDays});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(60),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _PlayStat('📅 플레이한 날', '$playDays일 / 30일', Colors.green),
          const SizedBox(width: 16),
          _PlayStat('🏆 잭팟 달성일', '$jackpotDays일', Colors.amber),
          const SizedBox(width: 16),
          _PlayStat('🔥 참여율', '${playDays > 0 ? (playDays / 30 * 100).toStringAsFixed(0) : "0"}%', theme.colorScheme.primary),
        ],
      ),
    );
  }
}

class _PlayStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _PlayStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
