import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../core/models/ygopro_card.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/ygo_card_back.dart';
import '../../domain/jackpot_battle.dart';

/// 잭팟 보상 — 오늘의 타겟 3장이 자동으로 순서대로 배틀하는 미니게임.
/// 수동 선택 없이 결과가 정해지며, 승수에 따라 보상 카드가 결정된다.
class JackpotBattlePage extends StatefulWidget {
  final List<YgoCard> targets;
  final List<YgoCard> hand;
  final List<YgoCard> pool;

  const JackpotBattlePage({
    super.key,
    required this.targets,
    required this.hand,
    required this.pool,
  });

  @override
  State<JackpotBattlePage> createState() => _JackpotBattlePageState();
}

enum _Phase { intro, battling, roundResult, finalResult }

class _JackpotBattlePageState extends State<JackpotBattlePage>
    with SingleTickerProviderStateMixin {
  late final JackpotBattleOutcome _outcome;
  _Phase _phase = _Phase.intro;
  int _roundIndex = 0;

  late final AnimationController _resultCtrl;
  late final Animation<double> _resultScale;

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _outcome = resolveJackpotBattle(
      targets: widget.targets,
      hand: widget.hand,
      pool: widget.pool,
      r: Random(),
    );
    _resultCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _resultScale = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _resultCtrl, curve: Curves.easeOutBack),
    );
    _scheduleNext(const Duration(milliseconds: 500), _startBattling);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _resultCtrl.dispose();
    super.dispose();
  }

  void _scheduleNext(Duration delay, VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, () {
      if (!mounted) return;
      action();
    });
  }

  void _startBattling() {
    setState(() => _phase = _Phase.battling);
    _scheduleNext(const Duration(milliseconds: 900), _revealRoundResult);
  }

  void _revealRoundResult() {
    setState(() => _phase = _Phase.roundResult);
    _resultCtrl.forward(from: 0);
    final isLast = _roundIndex == _outcome.rounds.length - 1;
    _scheduleNext(const Duration(milliseconds: 1400), () {
      if (isLast) {
        setState(() => _phase = _Phase.finalResult);
        _resultCtrl.forward(from: 0);
      } else {
        setState(() {
          _roundIndex++;
          _phase = _Phase.intro;
        });
        _scheduleNext(const Duration(milliseconds: 500), _startBattling);
      }
    });
  }

  void _finish() {
    Navigator.of(context).pop(_outcome);
  }

  @override
  Widget build(BuildContext context) {
    final round = _outcome.rounds[_roundIndex];

    return PopScope(
      canPop: _phase == _Phase.finalResult,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('🎰 잭팟 배틀'),
          automaticallyImplyLeading: _phase == _Phase.finalResult,
        ),
        body: SafeArea(
          child: switch (_phase) {
            _Phase.intro || _Phase.battling => _RoundBattleView(
                roundNumber: _roundIndex + 1,
                totalRounds: _outcome.rounds.length,
                round: round,
                revealed: _phase == _Phase.battling,
              ),
            _Phase.roundResult => _RoundResultView(
                roundNumber: _roundIndex + 1,
                totalRounds: _outcome.rounds.length,
                round: round,
                scaleAnim: _resultScale,
              ),
            _Phase.finalResult => _FinalResultView(
                outcome: _outcome,
                scaleAnim: _resultScale,
                onConfirm: _finish,
              ),
          },
        ),
      ),
    );
  }
}

String _modeLabel(BattleMode? mode) => switch (mode) {
      BattleMode.atk => '⚔️ 공격력 승부',
      BattleMode.def => '🛡️ 수비력 승부',
      null => '✨ 스펠 스피드 승부',
    };

class _RoundBattleView extends StatelessWidget {
  final int roundNumber;
  final int totalRounds;
  final JackpotRoundResult round;
  final bool revealed;

  const _RoundBattleView({
    required this.roundNumber,
    required this.totalRounds,
    required this.round,
    required this.revealed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'ROUND $roundNumber / $totalRounds',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            round.target.name,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          if (round.isSubstitute) ...[
            const SizedBox(height: 2),
            Text(
              '대타 출전: ${round.fighter.name}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _BattleCardDisplay(card: round.fighter, label: '내 카드', revealed: true),
              Text('VS',
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: theme.colorScheme.error,
                  )),
              _BattleCardDisplay(card: round.opponent, label: '상대', revealed: revealed),
            ],
          ),
          const SizedBox(height: 28),
          if (revealed)
            Text(_modeLabel(round.mode), style: theme.textTheme.bodyMedium)
          else
            const CircularProgressIndicator(),
        ],
      ),
    );
  }
}

class _RoundResultView extends StatelessWidget {
  final int roundNumber;
  final int totalRounds;
  final JackpotRoundResult round;
  final Animation<double> scaleAnim;

  const _RoundResultView({
    required this.roundNumber,
    required this.totalRounds,
    required this.round,
    required this.scaleAnim,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final won = round.won;
    final emoji = won ? '🏆' : '💀';
    final text = won ? '승리!' : '패배...';
    final color = won ? Colors.amber : theme.colorScheme.error;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'ROUND $roundNumber / $totalRounds',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          ScaleTransition(
            scale: scaleAnim,
            child: Column(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 56)),
                Text(text,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: color,
                    )),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            round.wentToTiebreak ? '$_tieNote (3판 2승 결정전)' : _modeLabel(round.mode),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _BattleCardDisplay(card: round.fighter, label: '내 카드', revealed: true),
              _BattleCardDisplay(card: round.opponent, label: '상대', revealed: true),
            ],
          ),
        ],
      ),
    );
  }

  static const _tieNote = '치열한 무승부 끝에 승부가 갈렸어요';
}

class _FinalResultView extends StatelessWidget {
  final JackpotBattleOutcome outcome;
  final Animation<double> scaleAnim;
  final VoidCallback onConfirm;

  const _FinalResultView({
    required this.outcome,
    required this.scaleAnim,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wins = outcome.wins;

    final title = outcome.isConsolation
        ? '아쉽지만... 위안 카드 획득!'
        : '$wins승 ${3 - wins}패 — 보상 카드 ${outcome.rewardCards.length}장 획득!';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 12),
          ScaleTransition(
            scale: scaleAnim,
            child: Column(
              children: [
                Text(outcome.isConsolation ? '🎁' : '🏆', style: const TextStyle(fontSize: 64)),
                const SizedBox(height: 8),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 14,
            runSpacing: 14,
            children: outcome.rewardCards
                .map((c) => _BattleCardDisplay(card: c, label: '획득', revealed: true))
                .toList(),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onConfirm,
              icon: const Icon(Icons.check),
              label: const Text('확인'),
            ),
          ),
        ],
      ),
    );
  }
}

class _BattleCardDisplay extends StatelessWidget {
  final YgoCard card;
  final String label;
  final bool revealed;

  const _BattleCardDisplay({
    required this.card,
    required this.label,
    required this.revealed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurfaceVariant,
            )),
        const SizedBox(height: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 80, maxWidth: 130),
          child: AspectRatio(
            aspectRatio: 59 / 86,
            child: Card(
              margin: EdgeInsets.zero,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              clipBehavior: Clip.antiAlias,
              child: revealed
                  ? AppNetworkImage(card.imageUrl, fit: BoxFit.contain,
                      fallback: (_) => const YgoCardBack(label: 'YGO'))
                  : const YgoCardBack(label: 'YGO'),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          revealed ? card.name : '???',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: theme.textTheme.labelSmall?.copyWith(fontSize: 9),
        ),
        if (revealed)
          Text(
            card.atk != null ? 'ATK ${card.atk} / DEF ${card.def ?? "-"}' : ' ',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
              fontSize: 9,
            ),
          ),
      ],
    );
  }
}
