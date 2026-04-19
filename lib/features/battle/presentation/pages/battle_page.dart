import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../core/models/ygopro_card.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/ygo_card_back.dart';
import '../../application/battle_stats_store.dart';

class BattlePage extends StatefulWidget {
  final List<YgoCard> drawnCards;
  final List<YgoCard> pool;

  const BattlePage({
    super.key,
    required this.drawnCards,
    required this.pool,
  });

  @override
  State<BattlePage> createState() => _BattlePageState();
}

enum _Phase { selectCard, battling, result }

class _BattlePageState extends State<BattlePage>
    with SingleTickerProviderStateMixin {
  _Phase _phase = _Phase.selectCard;
  YgoCard? _myCard;
  YgoCard? _opponentCard;
  String? _result; // 'win' | 'loss' | 'draw'

  // Stats
  int _wins = 0;
  int _losses = 0;
  int _draws = 0;

  late final AnimationController _resultCtrl;
  late final Animation<double> _resultScale;

  final _random = Random();

  @override
  void initState() {
    super.initState();
    _resultCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _resultScale = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _resultCtrl, curve: Curves.easeOutBack),
    );
    _loadStats();
  }

  @override
  void dispose() {
    _resultCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    final s = await BattleStatsStore.load();
    if (!mounted) return;
    setState(() {
      _wins = s.wins;
      _losses = s.losses;
      _draws = s.draws;
    });
  }

  void _selectCard(YgoCard card) {
    // Pick random opponent with ATK from pool
    final withAtk = widget.pool.where((c) => c.atk != null).toList();
    if (withAtk.isEmpty) return;
    final opponent = withAtk[_random.nextInt(withAtk.length)];

    setState(() {
      _myCard = card;
      _opponentCard = opponent;
      _phase = _Phase.battling;
    });

    // Delay for dramatic reveal
    Future.delayed(const Duration(milliseconds: 800), _resolveBattle);
  }

  void _resolveBattle() {
    final my = _myCard!.atk ?? 0;
    final op = _opponentCard!.atk ?? 0;

    String result;
    if (my > op) {
      result = 'win';
    } else if (my < op) {
      result = 'loss';
    } else {
      // ATK tie: compare DEF
      final myDef = _myCard!.def ?? 0;
      final opDef = _opponentCard!.def ?? 0;
      if (myDef > opDef) {
        result = 'win';
      } else if (myDef < opDef) {
        result = 'loss';
      } else {
        result = 'draw';
      }
    }

    setState(() {
      _result = result;
      _phase = _Phase.result;
    });
    _resultCtrl.forward(from: 0);
    BattleStatsStore.record(result: result);
    _loadStats();
  }

  void _reset() {
    _resultCtrl.reset();
    setState(() {
      _phase = _Phase.selectCard;
      _myCard = null;
      _opponentCard = null;
      _result = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('카드 배틀'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '$_wins승 $_losses패 $_draws무',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: _buildBody(theme),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    return switch (_phase) {
      _Phase.selectCard => _SelectPhase(
          cards: widget.drawnCards,
          onSelect: _selectCard,
        ),
      _Phase.battling => _BattlePhase(
          myCard: _myCard!,
          opponentCard: _opponentCard!,
          revealed: false,
        ),
      _Phase.result => _ResultPhase(
          myCard: _myCard!,
          opponentCard: _opponentCard!,
          result: _result!,
          scaleAnim: _resultScale,
          onRematch: _reset,
          onClose: () => Navigator.of(context).pop(),
        ),
    };
  }
}

// ──────────────────────────────────────────────
// Phase 1: Card selection
// ──────────────────────────────────────────────
class _SelectPhase extends StatelessWidget {
  final List<YgoCard> cards;
  final void Function(YgoCard) onSelect;

  const _SelectPhase({required this.cards, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final monsters = cards
        .where((c) => c.type.toLowerCase().contains('monster'))
        .toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '출전 카드를 선택하세요',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            'ATK(공격력)이 높을수록 유리합니다. 몬스터 카드만 출전 가능합니다.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          if (monsters.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('😞', style: TextStyle(fontSize: 48)),
                    const SizedBox(height: 12),
                    Text(
                      '몬스터 카드가 없습니다',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '몬스터 카드가 포함된 뽑기 결과로 다시 시도해보세요.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: LayoutBuilder(builder: (context, constraints) {
                final cols = (constraints.maxWidth / 130).floor().clamp(2, 6);
                return GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    childAspectRatio: 59 / 106,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: monsters.length,
                  itemBuilder: (_, i) => _SelectableCard(
                    card: monsters[i],
                    onTap: () => onSelect(monsters[i]),
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }
}

class _SelectableCard extends StatelessWidget {
  final YgoCard card;
  final VoidCallback onTap;

  const _SelectableCard({required this.card, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Card(
              margin: EdgeInsets.zero,
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              clipBehavior: Clip.antiAlias,
              child: AppNetworkImage(
                card.imageUrl,
                fit: BoxFit.contain,
                fallback: (_) => const YgoCardBack(label: 'YGO'),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            card.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(fontSize: 9),
          ),
          Text(
            card.atk != null ? 'ATK ${card.atk}' : 'ATK -',
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Phase 2: Battle animation
// ──────────────────────────────────────────────
class _BattlePhase extends StatelessWidget {
  final YgoCard myCard;
  final YgoCard opponentCard;
  final bool revealed;

  const _BattlePhase({
    required this.myCard,
    required this.opponentCard,
    required this.revealed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('배틀!', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _CardDisplay(card: myCard, label: 'MY', revealed: true),
              Text('VS',
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: theme.colorScheme.error,
                  )),
              _CardDisplay(card: opponentCard, label: '상대', revealed: false),
            ],
          ),
          const SizedBox(height: 32),
          const CircularProgressIndicator(),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Phase 3: Result
// ──────────────────────────────────────────────
class _ResultPhase extends StatelessWidget {
  final YgoCard myCard;
  final YgoCard opponentCard;
  final String result;
  final Animation<double> scaleAnim;
  final VoidCallback onRematch;
  final VoidCallback onClose;

  const _ResultPhase({
    required this.myCard,
    required this.opponentCard,
    required this.result,
    required this.scaleAnim,
    required this.onRematch,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final (resultEmoji, resultText, resultColor) = switch (result) {
      'win'  => ('🏆', '승리!',  Colors.amber),
      'loss' => ('💀', '패배...',  theme.colorScheme.error),
      _      => ('🤝', '무승부', theme.colorScheme.secondary),
    };

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ScaleTransition(
            scale: scaleAnim,
            child: Column(
              children: [
                Text(resultEmoji, style: const TextStyle(fontSize: 64)),
                const SizedBox(height: 8),
                Text(
                  resultText,
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: resultColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _CardDisplay(card: myCard, label: 'MY', revealed: true),
              Column(
                children: [
                  Text('VS',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: theme.colorScheme.error,
                      )),
                  const SizedBox(height: 8),
                  _AtkCompare(
                    myAtk: myCard.atk ?? 0,
                    opAtk: opponentCard.atk ?? 0,
                    result: result,
                  ),
                ],
              ),
              _CardDisplay(card: opponentCard, label: '상대', revealed: true),
            ],
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onRematch,
                  icon: const Icon(Icons.refresh),
                  label: const Text('다시 고르기'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onClose,
                  icon: const Icon(Icons.close),
                  label: const Text('닫기'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AtkCompare extends StatelessWidget {
  final int myAtk;
  final int opAtk;
  final String result;

  const _AtkCompare({required this.myAtk, required this.opAtk, required this.result});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final win = result == 'win';
    final lose = result == 'loss';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$myAtk',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: win ? Colors.green : lose ? theme.colorScheme.error : null,
          ),
        ),
        Text('vs', style: theme.textTheme.labelSmall),
        Text(
          '$opAtk',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: lose ? Colors.green : win ? theme.colorScheme.error : null,
          ),
        ),
        Text('ATK', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

class _CardDisplay extends StatelessWidget {
  final YgoCard card;
  final String label;
  final bool revealed;

  const _CardDisplay({required this.card, required this.label, required this.revealed});

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
          constraints: const BoxConstraints(minWidth: 72, maxWidth: 120),
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
            card.atk != null ? 'ATK ${card.atk}' : 'ATK -',
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
