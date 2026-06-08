import 'dart:async';
import 'dart:math';

import 'package:confetti/confetti.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api_client.dart';
import '../../../../core/providers/game_providers.dart';
import '../../../../core/app_colors.dart';
import '../../../../core/app_constants.dart';
import '../../../../core/app_strings.dart';
import '../../../../core/models/ygopro_card.dart';
import '../../../../core/services/cloud_sync_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/share_service.dart';
import '../../../../core/services/sound_service.dart';
import '../../../achievements/application/achievement_store.dart';
import '../../../achievements/domain/achievement.dart';
import '../../../achievements/presentation/pages/achievements_page.dart'
    show AchievementToast;
import '../../../battle/presentation/pages/battle_page.dart';
import '../../../level/domain/level_config.dart';
import '../../../level/presentation/widgets/level_badge.dart';
import '../../../level/presentation/widgets/level_up_overlay.dart';
import '../../../weekly_challenge/application/weekly_challenge_store.dart';
import '../../../weekly_challenge/domain/weekly_challenge.dart';
import '../../../weekly_challenge/presentation/widgets/weekly_challenge_widget.dart';
import '../../application/draw_history_store.dart';
import '../../application/jackpot_streak_store.dart';
import '../../application/play_log_store.dart';
import '../../application/random_draw_controller.dart';
import '../../application/today_rule_prefs.dart';
import '../../domain/draw_filter.dart';
import '../../domain/daily_slot_rule.dart';
import '../../domain/draw_history_entry.dart';
import '../../domain/jackpot_battle.dart';
import '../../domain/target_pity.dart';
import 'jackpot_battle_page.dart';
import '../widgets/batch_summary_dialog.dart';
import '../widgets/boss_countdown_widget.dart';
import '../widgets/card_detail_sheet.dart';
import '../widgets/count_picker_sheet.dart';
import '../widgets/draw_board.dart';
import '../widgets/landing.dart';
import '../widgets/target_preview_dialog.dart';
import '../widgets/slot_header.dart';
import '../widgets/slot_result_dialog.dart';

// -----------------------------
// 연속 뽑기 상태 묶음
// -----------------------------
class _BatchState {
  bool running = false;
  int token = 0;
  int total = 0;
  int done = 0;
  final Map<int, int> hist = {0: 0, 1: 0, 2: 0, 3: 0};

  void reset(int newTotal) {
    running = true;
    total = newTotal;
    done = 0;
    hist[0] = 0;
    hist[1] = 0;
    hist[2] = 0;
    hist[3] = 0;
  }
}

// -----------------------------
// Page
// -----------------------------
class RandomDrawPage extends ConsumerStatefulWidget {
  const RandomDrawPage({super.key});

  @override
  ConsumerState<RandomDrawPage> createState() => _RandomDrawPageState();
}

class _RandomDrawPageState extends ConsumerState<RandomDrawPage>
    with TickerProviderStateMixin {
  late final RandomDrawController _controller;

  // Confetti
  late final ConfettiController _confettiController;
  late final ConfettiController _confettiBossLeft;
  late final ConfettiController _confettiBossRight;

  // 보스 잭팟 연출
  late final AnimationController _flashController;
  late final AnimationController _bossTextController;
  // 결과 공개 클라이맥스 연출 (마지막 릴이 멈추는 순간 보드 전체에 입히는 짧은 플래시/펄스)
  late final AnimationController _climaxFlashController;
  bool _isBossJackpot = false;
  // 히트 카드 순차 스포트라이트: 현재 강조 중인 카드의 그리드 인덱스 (없으면 null)
  int? _spotlightIndex;

  // 잭팟 배틀 미니게임: 단일 뽑기에서 잭팟이 뜨면 결과 팝업 다음에 자동으로 연다.
  ({List<YgoCard> targets, List<YgoCard> hand})? _pendingJackpotBattle;
  // 배치 뽑기 중 발생한 잭팟 배틀들 — 배치 요약을 닫은 뒤 순서대로 보여준다.
  final List<({List<YgoCard> targets, List<YgoCard> hand})> _pendingBatchJackpotBattles = [];

  // 도전과제 토스트 큐
  final List<Achievement> _achievementQueue = [];
  bool _showingAchievement = false;
  // 배치 중 누적된 도전과제 (배치 완료 후 표시)
  final List<Achievement> _pendingBatchAchievements = [];

  // 레벨업 오버레이 큐
  final List<int> _levelUpQueue = [];
  bool _showingLevelUp = false;

  // 위클리 챌린지
  late WeeklyChallengeDef _weeklyChallenge;

  // 결과
  List<YgoCard> _cards = [];
  bool _loading = false;
  String? _error;
  bool _hasGenerated = false;

  // 랜딩
  bool _showLanding = true;

  // 남길 조건: 카드 수
  int _count = 5;

  // 애니메이션(아이콘 회전 + 릴)
  late final AnimationController _spinController;

  // 슬롯 피니시
  Timer? _finishTimer;
  List<int> _finishOrder = [];
  final Set<int> _stopped = <int>{};
  bool _spinning = false;

  // 릴 (ValueNotifier로 변경 → 그리드만 재빌드)
  Timer? _reelTimer;
  final ValueNotifier<List<int>> _reelNotifier = ValueNotifier<List<int>>([]);

  // 스크롤
  final ScrollController _gridScrollController = ScrollController();

  // util
  final Random _random = Random();

  // 오늘 룰 (exact/category)
  DailySlotRule? _todayRule;

  // Draw 완료를 “진짜 끝까지” 기다리기 위한 completer
  Completer<void>? _drawCompleter;

  // 연속뽑기(배치)
  final _BatchState _batch = _BatchState();

  String _friendlyError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('timeout') || msg.contains('timedout')) {
      return '네트워크 응답이 너무 느립니다.\n잠시 후 다시 시도해 주세요.';
    }
    if (msg.contains('socketexception') ||
        msg.contains('network') ||
        msg.contains('connection')) {
      return '인터넷 연결을 확인해 주세요.';
    }
    if (msg.contains('api error: 400')) {
      return '검색 조건에 해당하는 카드가 없습니다.\n필터를 변경해 보세요.';
    }
    if (msg.contains('api error')) {
      return '카드 데이터를 불러오지 못했습니다.\n잠시 후 다시 시도해 주세요.';
    }
    return '알 수 없는 오류가 발생했습니다.\n잠시 후 다시 시도해 주세요.';
  }

  @override
  void initState() {
    super.initState();
    _controller = RandomDrawController(YgoApiClient());

    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _confettiController = ConfettiController(
      duration: const Duration(seconds: 4),
    );
    _confettiBossLeft = ConfettiController(
      duration: const Duration(seconds: 5),
    );
    _confettiBossRight = ConfettiController(
      duration: const Duration(seconds: 5),
    );
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _bossTextController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
    _climaxFlashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );

    _weeklyChallenge = pickWeeklyChallenge(now: DateTime.now());

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final todayKey = _todayKey(DateTime.now());

      _todayRule = await TodayRulePrefs.load(count: _count, todayKey: todayKey);
      if (!mounted) return;
      if (_todayRule == null) {
        await _ensureTodayRuleFromDailyPool();
      }
      // 로컬에 기록이 있으면 랜딩 스킵 (새로고침 시)
      ref.read(totalDrawsProvider.future).then((draws) {
        if (mounted && draws > 0) setState(() => _showLanding = false);
      });
      // 로그인 직후 클라우드 데이터가 아직 반영 안 됐을 수 있으므로 sync 후 재로드
      await CloudSyncService.downloadAndMerge();
      if (!mounted) return;
      ref.invalidate(xpProvider);
      ref.invalidate(collectionProvider);
      ref.invalidate(favoriteIdsProvider);
      ref.invalidate(totalDrawsProvider);
      ref.invalidate(streakProvider);
      ref.read(totalDrawsProvider.future).then((draws) {
        if (mounted && draws > 0) setState(() => _showLanding = false);
      });
      // 알림: 오늘 아직 안 뽑았으면 브라우저 알림
      if (NotificationService.isSupported) {
        final playLog = await PlayLogStore.load();
        final todayStr = _todayKey(DateTime.now());
        final playedToday = playLog.playDates.contains(todayStr);
        await NotificationService.showIfNotPlayedToday(
          playedToday: playedToday,
        );
      }
    });
  }

  @override
  void dispose() {
    _finishTimer?.cancel();
    _reelTimer?.cancel();
    _reelNotifier.dispose();
    _gridScrollController.dispose();
    _spinController.dispose();
    _confettiController.dispose();
    _confettiBossLeft.dispose();
    _confettiBossRight.dispose();
    _flashController.dispose();
    _bossTextController.dispose();
    _climaxFlashController.dispose();
    super.dispose();
  }

  @override
  void reassemble() {
    super.reassemble();
    _cancelAllRunnersForHotReload();

    _spinning = false;
    _loading = false;
    _stopped.clear();
    _finishOrder.clear();
  }

  void _cancelAllRunnersForHotReload() {
    _finishTimer?.cancel();
    _finishTimer = null;

    _reelTimer?.cancel();
    _reelTimer = null;

    if (_spinController.isAnimating) _spinController.stop();
    _spinController.reset();
  }

  // -----------------------------
  // Filter (count only)
  // -----------------------------
  DrawFilter _buildFilter() {
    return DrawFilter(
      count: _count,
      type: null,
      attribute: null,
      levelExpr: null,
      atkExpr: null,
    );
  }

  String _currentFilterSummary() {
    switch (_count) {
      case 3:
        return AppStrings.modeChallenge;
      case 5:
        return AppStrings.modeDefault;
      case 7:
        return AppStrings.modeComfort;
      default:
        return '$_count장';
    }
  }

  // -----------------------------
  // Slot rule helpers
  // -----------------------------
  String _todayKey(DateTime now) {
    final d = DateUtils.dateOnly(now);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _ensureTodayRuleFromDailyPool() async {
    final key = _todayKey(DateTime.now());
    final count = _count;

    if (_todayRule != null && _todayRule!.dateKey == key) return;

    debugPrint('[TodayRule] 캐시 미스 — prefs 로드 시도 (count=$count, date=$key)');
    _todayRule = await TodayRulePrefs.load(count: count, todayKey: key);
    if (_todayRule != null && _todayRule!.dateKey == key) {
      debugPrint('[TodayRule] prefs에서 복원 성공 (kind=${_todayRule!.kind.name})');
      if (mounted) setState(() {});
      return;
    }

    final dailyPool = await _controller.ensureDailyPool();
    debugPrint('[TodayRule] 풀 크기: ${dailyPool.length}, 새 룰 생성 중...');
    _todayRule = buildTodayRule(dailyPool, now: DateTime.now(), count: count);
    debugPrint('[TodayRule] 생성 완료 — kind=${_todayRule!.kind.name}');

    await TodayRulePrefs.save(_todayRule!, count: count);

    if (mounted) setState(() {});
  }

  // -----------------------------
  // Core: Run Draw (끝까지 await)
  // -----------------------------
  Future<void> _runDraw({required bool showPopup}) async {
    await _ensureTodayRuleFromDailyPool();

    if (_drawCompleter != null && !_drawCompleter!.isCompleted) {
      return;
    }

    _finishTimer?.cancel();
    _finishTimer = null;
    _reelTimer?.cancel();
    _reelTimer = null;

    _stopped.clear();
    _finishOrder = [];

    final completer = Completer<void>();
    _drawCompleter = completer;

    setState(() {
      _loading = true;
      _spinning = true;
      _error = null;
      _hasGenerated = true;
      _isBossJackpot = false;
    });

    SoundService.playSpinStart();
    _spinController.repeat();

    final filter = _buildFilter();

    try {
      final drawn = await _controller.generateDraw(filter);
      if (!mounted) {
        if (!completer.isCompleted) completer.complete();
        return;
      }

      final result = await _maybeInjectPity(drawn);
      if (!mounted) {
        if (!completer.isCompleted) completer.complete();
        return;
      }

      setState(() => _cards = result);

      if (result.isEmpty) {
        _endSpin(showPopup: showPopup);
        if (!completer.isCompleted) completer.complete();
        return;
      }

      _reelNotifier.value = List<int>.generate(result.length, (_) => 0);

      _reelTimer = Timer.periodic(AppConstants.reelTickInterval, (_) {
        if (!mounted) return;
        if (!_spinning) return;
        if (_cards.isEmpty) return;

        final prev = _reelNotifier.value;
        final next = List<int>.of(prev);
        for (var i = 0; i < _cards.length; i++) {
          if (_stopped.contains(i)) continue;
          next[i] = (next[i] + 1) % _cards.length;
        }
        _reelNotifier.value = next;
      });

      _finishOrder = List<int>.generate(result.length, (i) => i)
        ..shuffle(_random);

      _haptic(HapticFeedback.mediumImpact);

      var cursor = 0;

      final total = _finishOrder.length;

      void scheduleNextStop() {
        _finishTimer = Timer(_stopDelayFor(cursor, total), () {
          if (!mounted) return;

          final idx = _finishOrder[cursor];
          setState(() => _stopped.add(idx));
          SoundService.playReelTick();
          _haptic(HapticFeedback.selectionClick);

          cursor++;
          if (cursor >= total) {
            _finishTimer = null;

            _haptic(HapticFeedback.mediumImpact);
            _climaxFlashController.forward(from: 0);
            _endSpin(showPopup: showPopup);

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              if (_gridScrollController.hasClients) {
                _gridScrollController.animateTo(
                  0,
                  duration: AppConstants.reelScrollDuration,
                  curve: Curves.easeOutCubic,
                );
              }
            });

            if (!completer.isCompleted) completer.complete();
          } else {
            scheduleNextStop();
          }
        });
      }

      scheduleNextStop();
    } catch (e) {
      if (!mounted) {
        if (!completer.isCompleted) completer.complete();
        return;
      }
      setState(() => _error = _friendlyError(e));
      _endSpin(showPopup: false);
      if (!completer.isCompleted) completer.complete();
    }

    return completer.future;
  }

  /// 천장(타겟 카드) 로직: 오늘의 타겟 3장 중 결과에 없는 카드가 있을 때,
  /// 미스 횟수에 따른 확률(또는 하드 천장 보장)로 부족한 타겟 카드를 결과에 끼워 넣는다.
  /// 하드 천장(missCount >= kPityHard)에서는 부족한 타겟을 모두 채워 넣어 확정 잭팟을 만든다.
  Future<List<YgoCard>> _maybeInjectPity(List<YgoCard> drawn) async {
    if (drawn.isEmpty) return drawn;

    final rule = _todayRule;
    if (rule == null || rule.targets.isEmpty) return drawn;

    final pity = ref.read(targetPityProvider).valueOrNull;
    final missCount = pity?.missCount ?? 0;

    final missingIds = <int>[];
    for (final t in rule.targets) {
      final id = t.cardId;
      if (id == null) continue;
      if (drawn.any((c) => c.id == id)) continue;
      missingIds.add(id);
    }
    if (missingIds.isEmpty) return drawn;

    final guaranteed = missCount >= kPityHard;
    final toInject = <int>[];
    for (final id in missingIds) {
      if (guaranteed || shouldInjectPityTarget(missCount, _random)) {
        toInject.add(id);
      }
    }
    if (toInject.isEmpty) return drawn;

    final injected = [...drawn];
    final usedSlots = <int>{};
    for (final id in toInject) {
      final card = await _controller.fetchCardById(id);
      if (card == null) continue;

      int slot;
      do {
        slot = _random.nextInt(injected.length);
      } while (usedSlots.length < injected.length && usedSlots.contains(slot));
      usedSlots.add(slot);
      injected[slot] = card;
    }
    return injected;
  }

  /// 릴이 멈추는 간격을 뒤로 갈수록 점점 늘려 서스펜스를 만든다.
  /// 첫 칸은 기본 간격으로 빠르게, 마지막 칸으로 갈수록 약 4.5배까지 느려진다.
  Duration _stopDelayFor(int cursor, int total) {
    if (total <= 1) return AppConstants.reelStopInterval;
    final progress = cursor / (total - 1);
    final baseMs = AppConstants.reelStopInterval.inMilliseconds;
    final extraMs = (baseMs * 3.5 * progress * progress).round();
    return Duration(milliseconds: baseMs + extraMs);
  }

  void _endSpin({required bool showPopup}) {
    _reelTimer?.cancel();
    _reelTimer = null;

    if (!mounted) return;

    setState(() {
      _spinning = false;
      _loading = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final hits = countSlotHits(cards: _cards, rule: _todayRule);

      // Sound feedback
      if (hits >= 3) {
        if (_todayRule?.kind == DayKind.boss) {
          SoundService.playBossJackpot();
        } else {
          SoundService.playJackpot();
        }
      } else if (hits > 0) {
        SoundService.playHit();
      }

      if (showPopup) {
        if (hits > 0) {
          await _runHitSpotlight(_hitCardIndices());
          if (!mounted) return;
          _showSingleHitPopup(hits);
        }
        _saveDrawHistory(hits);
      }

      if (showPopup && hits >= 3) {
        _pendingJackpotBattle = (
          targets: _matchedTargetCards(),
          hand: List<YgoCard>.from(_cards),
        );
      }

      await _onDrawComplete(hits, isBatch: !showPopup);

      // 잭팟 배틀 미니게임 — 잭팟 팝업과 겹치지 않도록 한 박자 늦게 연다.
      if (showPopup && _pendingJackpotBattle != null) {
        final info = _pendingJackpotBattle!;
        _pendingJackpotBattle = null;
        await Future.delayed(const Duration(milliseconds: 900));
        if (mounted) {
          await _runJackpotBattle(targets: info.targets, hand: info.hand);
        }
      }
    });
  }

  /// 오늘의 타겟과 일치하는 카드의 그리드 인덱스 목록.
  List<int> _hitCardIndices() {
    final rule = _todayRule;
    if (rule == null || _cards.isEmpty) return const [];

    final indices = <int>[];
    for (var i = 0; i < _cards.length; i++) {
      final card = _cards[i];
      if (rule.targets.any((t) => matchesTarget(card: card, t: t))) {
        indices.add(i);
      }
    }
    return indices;
  }

  /// 적중한 카드를 한 장씩 순서대로 확대+발광시켜 시선을 모으고,
  /// 그 사이 나머지 카드는 살짝 어둡게 해 스포트라이트 효과를 만든다.
  Future<void> _runHitSpotlight(List<int> indices) async {
    if (indices.isEmpty || !mounted) return;

    for (final idx in indices) {
      if (!mounted) return;
      setState(() => _spotlightIndex = idx);
      SoundService.playHit();
      _haptic(HapticFeedback.lightImpact);
      await Future.delayed(const Duration(milliseconds: 620));
    }

    if (!mounted) return;
    setState(() => _spotlightIndex = null);
    await Future.delayed(const Duration(milliseconds: 160));
  }

  // -----------------------------
  // Batch Draw — 천장 포인트 베팅 미니게임 (30/50/100/150/200/250/300/350)
  // -----------------------------
  void _openBatchPicker() {
    if (_loading || _spinning) return;

    final points = ref.read(targetPityProvider).valueOrNull?.missCount ?? 0;

    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              MediaQuery.viewInsetsOf(ctx).bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '연속 뽑기 — 천장 포인트 베팅',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '현재 천장 포인트는 ${points}P예요. 횟수를 고르면 그만큼 포인트를 걸고 '
                  '한 번에 돌려요. 그 안에서 잭팟이 한 번이라도 터지면 보너스 카드와 함께 '
                  '승리하고, 못 터지면 건 만큼 포인트를 잃어요.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                for (var i = 0; i < kBatchBetSizes.length; i += 2) ...[
                  if (i > 0) const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _batchChoice(ctx, kBatchBetSizes[i], points)),
                      const SizedBox(width: 10),
                      Expanded(child: _batchChoice(ctx, kBatchBetSizes[i + 1], points)),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('닫기'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _batchChoice(BuildContext ctx, int n, int points) {
    final bet = batchBetAmount(n);
    final enabled = points >= bet;
    return ElevatedButton(
      onPressed: enabled
          ? () {
              Navigator.of(ctx).pop();
              _startBatch(n);
            }
          : null,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$n회', style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(
            enabled ? '🎯 ${bet}P 베팅' : '🎯 ${bet}P 필요',
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
    );
  }

  Future<void> _startBatch(int total) async {
    if (_batch.running) return;

    final pointsBefore = ref.read(targetPityProvider).valueOrNull?.missCount ?? 0;
    final betAmount = batchBetAmount(total);
    if (pointsBefore < betAmount) return;

    setState(() => _batch.reset(total));

    final token = ++_batch.token;
    var jackpotOccurred = false;

    for (var i = 0; i < total; i++) {
      if (!mounted) break;
      if (token != _batch.token) break;

      await _runDraw(showPopup: false);

      if (!mounted) break;
      if (token != _batch.token) break;

      final hits = countSlotHits(cards: _cards, rule: _todayRule).clamp(0, 3);
      _batch.hist[hits] = (_batch.hist[hits] ?? 0) + 1;

      if (hits >= 3) {
        jackpotOccurred = true;
        if (_todayRule?.kind == DayKind.boss) {
          unawaited(_triggerBossJackpot());
        } else {
          _confettiController.play();
        }
        await _doUpdateStreak();
        _pendingBatchJackpotBattles.add((
          targets: _matchedTargetCards(),
          hand: List<YgoCard>.from(_cards),
        ));
      }

      setState(() => _batch.done = i + 1);

      await Future.delayed(AppConstants.batchDrawDelay);
    }

    if (!mounted) return;
    final cancelled = token != _batch.token;

    setState(() => _batch.running = false);

    if (cancelled) return;

    // 천장 포인트 베팅 정산 — 잭팟이 한 번이라도 터졌으면 승리, 아니면 패배.
    final betOutcome = resolveBatchBet(
      currentPoints: pointsBefore,
      batchSize: total,
      jackpotOccurred: jackpotOccurred,
    );
    await ref.read(targetPityProvider.notifier).applyBatchBetResult(
          newMissCount: betOutcome.pointsAfter,
          jackpotOccurred: jackpotOccurred,
        );

    var bonusCards = const <YgoCard>[];
    if (betOutcome.won && betOutcome.bonusCardCount > 0) {
      bonusCards = _drawBonusCards(betOutcome.bonusCardCount);
      if (bonusCards.isNotEmpty) {
        await ref.read(collectionProvider.notifier).addCards(
              bonusCards
                  .map((c) => (id: c.id, name: c.name, imageUrl: c.imageUrl))
                  .toList(),
            );
      }
    }

    // 배치 완료 후 레벨업 + 도전과제 표시
    if (_levelUpQueue.isNotEmpty) _processLevelUpQueue();
    if (_pendingBatchAchievements.isNotEmpty) {
      _achievementQueue.addAll(_pendingBatchAchievements);
      _pendingBatchAchievements.clear();
      _processAchievementQueue();
    }

    CloudSyncService.uploadAfterDraw();
    if (mounted) {
      final streakData =
          ref.read(streakProvider).valueOrNull ?? JackpotStreakData.empty;
      await BatchSummaryDialog.show(
        context,
        total: _batch.total,
        hist: Map.from(_batch.hist),
        streak: streakData.streak,
        best: streakData.best,
        bet: betOutcome,
      );

      // 배치 중 발생한 잭팟 배틀 — 배치 요약을 닫은 다음 순서대로 보여준다.
      while (_pendingBatchJackpotBattles.isNotEmpty && mounted) {
        final info = _pendingBatchJackpotBattles.removeAt(0);
        await _runJackpotBattle(targets: info.targets, hand: info.hand);
      }
    }
  }

  /// 베팅 승리 보너스 카드를 데일리 풀에서 무작위로 뽑는다.
  List<YgoCard> _drawBonusCards(int count) {
    final pool = List<YgoCard>.from(_controller.cachedDailyPool);
    if (pool.isEmpty) return const [];
    pool.shuffle(_random);
    return pool.take(count).toList();
  }

  void _stopBatchDraw() {
    _batch.token++;
    if (!mounted) return;
    setState(() => _batch.running = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('연속 뽑기를 중단했습니다. (${_batch.done} / ${_batch.total}회)'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // -----------------------------
  // Boss Jackpot Effect
  // -----------------------------
  Future<void> _triggerBossJackpot() async {
    setState(() => _isBossJackpot = true);
    _confettiController.play();
    _confettiBossLeft.play();
    _confettiBossRight.play();
    _flashController.forward(from: 0);
    _bossTextController.forward(from: 0);
    SoundService.playBossJackpot();
    _haptic(HapticFeedback.heavyImpact);
    await Future.delayed(const Duration(milliseconds: 120));
    _haptic(HapticFeedback.heavyImpact);
    await Future.delayed(const Duration(milliseconds: 120));
    _haptic(HapticFeedback.heavyImpact);
  }

  // -----------------------------
  // Popups
  // -----------------------------
  void _showSingleHitPopup(int hits) {
    final rule = _todayRule;
    if (rule == null) return;

    final isBoss = hits >= 3 && _todayRule?.kind == DayKind.boss;

    final title = isBoss
        ? '👑 BOSS JACKPOT!!'
        : hits >= 3
        ? '🎰 잭팟!'
        : hits == 2
        ? '🔥 2개 적중!'
        : '✨ 1개 적중!';

    final message = isBoss
        ? '전설의 잭팟 달성! 특정 카드 3장을 모두 뽑았어요!'
        : hits >= 3
        ? '오늘의 타겟 3개 전부 맞췄어요!'
        : hits == 2
        ? '거의 잭팟… 한 번만 더!'
        : '적중! 운이 달아오르는 중 🔥';

    if (hits >= 3) {
      if (isBoss) {
        unawaited(_triggerBossJackpot());
      } else {
        _confettiController.play();
      }
      unawaited(_doUpdateStreak());
    }

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (ctx, anim, secAnim) => SlotResultDialog(
        hits: hits,
        targets: 3,
        title: title,
        message: message,
        rule: rule,
        cards: _cards,
        isBossJackpot: isBoss,
        onShare: () => _shareResult(hits),
      ),
      transitionBuilder: (ctx, animation, _, child) {
        final beginScale = isBoss ? 0.3 : 0.75;
        final scale = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        );
        return ScaleTransition(
          scale: Tween<double>(begin: beginScale, end: 1.0).animate(scale),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
    );
  }

  // -----------------------------
  // Haptic
  // -----------------------------
  void _haptic(Future<void> Function() action) {
    if (kIsWeb) return;
    final p = defaultTargetPlatform;
    final isMobile = p == TargetPlatform.android || p == TargetPlatform.iOS;
    if (!isMobile) return;

    try {
      action();
    } catch (e) {
      debugPrint('[Haptic] 피드백 실패 (무시): $e');
    }
  }

  // -----------------------------
  // Draw history
  // -----------------------------
  void _saveDrawHistory(int hits) {
    if (_cards.isEmpty) return;
    final entry = DrawHistoryEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      hits: hits,
      mode: _count,
      cards: _cards
          .map(
            (c) =>
                DrawHistoryCard(id: c.id, name: c.name, imageUrl: c.imageUrl),
          )
          .toList(),
    );
    DrawHistoryStore.addEntry(entry); // fire-and-forget
  }

  Future<void> _onDrawComplete(int hits, {required bool isBatch}) async {
    if (_cards.isEmpty) return;

    // 컬렉션(전리품)은 매 뽑기가 아니라 잭팟 배틀의 보상 카드로만 채워진다.
    final newSize = ref.read(collectionSizeProvider);

    // 총 뽑기 횟수
    final newDraws = await ref.read(totalDrawsProvider.notifier).increment();

    // 플레이 로그 (잭팟 여부)
    final isJackpot = hits >= 3;
    await PlayLogStore.recordPlay(jackpot: isJackpot);

    final streakData =
        ref.read(streakProvider).valueOrNull ?? JackpotStreakData.empty;

    // 도전과제 체크
    final event = AchievementEvent(
      drew: true,
      hitOccurred: hits > 0,
      jackpot: isJackpot,
      bossJackpot: isJackpot && _todayRule?.kind == DayKind.boss,
      mode: _count,
      isBatch: isBatch,
      currentStreak: streakData.streak,
      totalJackpots: streakData.total,
      totalDraws: newDraws,
      collectionSize: newSize,
    );
    final newAchievements = await AchievementStore.checkAndUnlock(event);

    // XP 적립
    final xpGain = calcXpGain(
      hits: hits,
      bossJackpot: isJackpot && _todayRule?.kind == DayKind.boss,
      isBatch: isBatch,
    );
    final lvResult = await ref.read(xpProvider.notifier).addXp(xpGain);

    // 위클리 챌린지 완료 체크
    if (_weeklyChallenge.isCompleted(_cards)) {
      await WeeklyChallengeStore.recordCompletion();
    }

    // 천장(타겟 카드) 진행도 갱신 — 잭팟이면 missCount 리셋, 아니면 +1
    // 연속 뽑기는 베팅 미니게임이므로 매 뽑기마다 천장을 건드리지 않고,
    // 베팅 결과로 한 번에 정산한다 (_startBatch 참고).
    if (!isBatch) {
      await ref.read(targetPityProvider.notifier).recordDraw(jackpot: isJackpot);
    }

    if (!mounted) return;
    debugPrint('[Stats] 총 뽑기: $newDraws회, 도감: $newSize종, Lv.${lvResult.level}');

    // 레벨업 알림
    if (lvResult.level > lvResult.oldLevel) {
      for (int lv = lvResult.oldLevel + 1; lv <= lvResult.level; lv++) {
        _levelUpQueue.add(lv);
      }
      if (!isBatch) _processLevelUpQueue();
    }

    if (newAchievements.isNotEmpty) {
      if (isBatch) {
        _pendingBatchAchievements.addAll(newAchievements);
      } else {
        _achievementQueue.addAll(newAchievements);
        _processAchievementQueue();
      }
    }

    if (!isBatch) CloudSyncService.uploadAfterDraw();
  }

  void _processLevelUpQueue() {
    if (_showingLevelUp || _levelUpQueue.isEmpty) return;
    if (!mounted) return;
    setState(() => _showingLevelUp = true);
  }

  void _onLevelUpDone() {
    if (!mounted) return;
    setState(() {
      if (_levelUpQueue.isNotEmpty) _levelUpQueue.removeAt(0);
      _showingLevelUp = false;
    });
    if (_levelUpQueue.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) setState(() => _showingLevelUp = true);
      });
    }
  }

  void _processAchievementQueue() {
    if (_showingAchievement || _achievementQueue.isEmpty) return;
    if (!mounted) return;
    setState(() => _showingAchievement = true);
  }

  void _onAchievementToastDone() {
    if (!mounted) return;
    setState(() {
      if (_achievementQueue.isNotEmpty) _achievementQueue.removeAt(0);
      _showingAchievement = false;
    });
    // show next
    if (_achievementQueue.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) setState(() => _showingAchievement = true);
      });
    }
  }

  Future<void> _toggleFavorite(int cardId) async {
    final isNow = await ref.read(favoriteIdsProvider.notifier).toggle(cardId);
    if (!mounted) return;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isNow ? '🔖 즐겨찾기에 추가했습니다' : '즐겨찾기에서 제거했습니다'),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _shareResult(int hits) {
    if (_cards.isEmpty) return;
    final rule = _todayRule;
    final dayType = rule?.kind == DayKind.boss ? '👑 보스데이' : '🎯 일반';
    final hitEmoji = hits >= 3
        ? '🎰 잭팟!'
        : hits == 2
        ? '🔥 2히트'
        : hits == 1
        ? '✨ 1히트'
        : '💨 미스';
    final cardNames = _cards.take(3).map((c) => c.name).join(', ');
    final text =
        '유희왕 슬롯 결과\n'
        '$dayType | $hitEmoji\n'
        '뽑은 카드: $cardNames${_cards.length > 3 ? ' 외 ${_cards.length - 3}장' : ''}\n'
        '🔥 연속 잭팟: ${ref.read(streakProvider).valueOrNull?.streak ?? 0}일';
    _showShareDialog(text);
  }

  void _showShareDialog(String text) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('📤 결과 공유'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(text, style: Theme.of(ctx).textTheme.bodyMedium),
            ),
            const SizedBox(height: 12),
            if (ShareService.isClipboardSupported)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final ok = await ShareService.copyToClipboard(text);
                    if (ctx.mounted) {
                      Navigator.of(ctx).pop();
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(ok ? '✅ 클립보드에 복사했습니다' : '복사에 실패했습니다'),
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('클립보드에 복사'),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  void _showCardDetail(YgoCard card) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.70,
      ),
      builder: (_) => CardDetailSheet(
        card: card,
        isFavorite:
            ref.read(favoriteIdsProvider).valueOrNull?.contains(card.id) ??
            false,
        onToggleFavorite: () => _toggleFavorite(card.id),
        onShare: () =>
            _shareResult(countSlotHits(cards: _cards, rule: _todayRule)),
      ),
    );
  }

  void _openBattle() {
    if (_cards.isEmpty) return;
    final pool = _controller.cachedDailyPool;
    if (pool.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BattlePage(drawnCards: _cards, pool: pool),
      ),
    );
  }

  // -----------------------------
  // Jackpot streak (delegated to JackpotStreakStore)
  // -----------------------------
  Future<void> _doUpdateStreak() async {
    await ref.read(streakProvider.notifier).updateStreak();
  }

  // -----------------------------
  // Jackpot battle minigame (잭팟 보상)
  // -----------------------------

  /// 오늘의 타겟과 일치한 카드 3장을 뽑힌 결과에서 찾아 반환한다 (잭팟 = 항상 3장).
  List<YgoCard> _matchedTargetCards() {
    final rule = _todayRule;
    if (rule == null) return const [];

    final result = <YgoCard>[];
    for (final t in rule.targets) {
      final id = t.cardId;
      if (id == null) continue;
      for (final c in _cards) {
        if (c.id == id) {
          result.add(c);
          break;
        }
      }
    }
    return result;
  }

  /// 잭팟 배틀 미니게임을 열고, 결과로 받은 보상 카드를 컬렉션(전리품)에 추가한다.
  Future<void> _runJackpotBattle({
    required List<YgoCard> targets,
    required List<YgoCard> hand,
  }) async {
    if (!mounted || targets.isEmpty) return;
    final pool = _controller.cachedDailyPool;

    final outcome = await Navigator.of(context).push<JackpotBattleOutcome>(
      MaterialPageRoute(
        builder: (_) => JackpotBattlePage(targets: targets, hand: hand, pool: pool),
      ),
    );
    if (outcome == null || !mounted) return;

    final newSize = await ref.read(collectionProvider.notifier).addCards(
          outcome.rewardCards
              .map((c) => (id: c.id, name: c.name, imageUrl: c.imageUrl))
              .toList(),
        );
    debugPrint('[JackpotBattle] ${outcome.wins}승, 보상 ${outcome.rewardCards.length}장 (도감: $newSize종)');

    // 전리품 획득으로 도감 수집 도전과제가 즉시 갱신될 수 있으므로 다시 체크한다.
    final newAchievements = await AchievementStore.checkAndUnlock(
      AchievementEvent(collectionSize: newSize),
    );
    if (newAchievements.isNotEmpty && mounted) {
      _achievementQueue.addAll(newAchievements);
      _processAchievementQueue();
    }
  }

  void _openExactTargetPreview(SlotTarget t) {
    TargetPreviewDialog.show(context, t);
  }

  // -----------------------------
  // UI
  // -----------------------------
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mobileCompact = MediaQuery.sizeOf(context).width < 480;

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            toolbarHeight: mobileCompact ? 44 : kToolbarHeight,
            title: const Text('유희왕 슬롯'),
            actions: [
              // 레벨 배지
              Padding(
                padding: EdgeInsets.symmetric(vertical: mobileCompact ? 6 : 10),
                child: LevelBadge(
                  xp: ref.watch(xpProvider).valueOrNull ?? 0,
                  compact: true,
                ),
              ),
              const SizedBox(width: 4),
              // 뮤트 토글
              StatefulBuilder(
                builder: (_, setBtn) => IconButton(
                  icon: Icon(
                    SoundService.muted ? Icons.volume_off : Icons.volume_up,
                    size: 22,
                  ),
                  tooltip: SoundService.muted ? '소리 켜기' : '소리 끄기',
                  onPressed: () {
                    SoundService.toggleMute();
                    setBtn(() {});
                  },
                ),
              ),
            ],
          ),
          body: SafeArea(child: _buildHome(theme)),
        ),
        IgnorePointer(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              numberOfParticles: 40,
              gravity: 0.2,
              colors: const [
                AppColors.gold,
                Colors.purple,
                Colors.red,
                Color(0xFF00BFFF),
                Colors.green,
              ],
            ),
          ),
        ),
        // 보스 잭팟: 골드 플래시
        IgnorePointer(
          child: AnimatedBuilder(
            animation: _flashController,
            builder: (_, _) {
              final t = _flashController.value;
              final opacity = (t < 0.3 ? (t / 0.3) : (1.0 - t) / 0.7) * 0.45;
              return Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: Container(color: AppColors.gold),
              );
            },
          ),
        ),
        // 보스 잭팟: BOSS JACKPOT 텍스트
        IgnorePointer(
          child: AnimatedBuilder(
            animation: _bossTextController,
            builder: (_, _) {
              final t = _bossTextController.value;
              final scale = t < 0.2
                  ? (t / 0.2) * 1.15
                  : t < 0.3
                  ? 1.15 - ((t - 0.2) / 0.1 * 0.15)
                  : 1.0;
              final opacity =
                  (t < 0.1
                          ? t / 0.1
                          : t > 0.7
                          ? (1.0 - t) / 0.3
                          : 1.0)
                      .clamp(0.0, 1.0);
              return Opacity(
                opacity: opacity,
                child: Transform.scale(
                  scale: scale,
                  child: const Center(
                    child: Text(
                      'BOSS\nJACKPOT!!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 62,
                        fontWeight: FontWeight.w900,
                        color: AppColors.gold,
                        letterSpacing: 2,
                        shadows: [
                          Shadow(
                            color: Colors.black87,
                            blurRadius: 16,
                            offset: Offset(0, 4),
                          ),
                          Shadow(color: Colors.black54, blurRadius: 32),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        // 보스 잭팟: 좌/우 컨페티
        IgnorePointer(
          child: Align(
            alignment: Alignment.topLeft,
            child: ConfettiWidget(
              confettiController: _confettiBossLeft,
              blastDirection: pi * -0.25,
              numberOfParticles: 60,
              gravity: 0.3,
              colors: const [
                AppColors.gold,
                Colors.orange,
                Colors.red,
                Colors.white,
              ],
            ),
          ),
        ),
        IgnorePointer(
          child: Align(
            alignment: Alignment.topRight,
            child: ConfettiWidget(
              confettiController: _confettiBossRight,
              blastDirection: pi * 1.25,
              numberOfParticles: 60,
              gravity: 0.3,
              colors: const [
                AppColors.gold,
                Colors.orange,
                Colors.red,
                Colors.white,
              ],
            ),
          ),
        ),
        // 레벨업 오버레이
        if (_showingLevelUp && _levelUpQueue.isNotEmpty)
          Positioned.fill(
            child: IgnorePointer(
              ignoring: false,
              child: GestureDetector(
                onTap: _onLevelUpDone,
                child: Container(
                  color: Colors.black45,
                  alignment: Alignment.center,
                  child: LevelUpOverlay(
                    key: ValueKey('lvup_${_levelUpQueue.first}'),
                    newLevel: _levelUpQueue.first,
                    onDone: _onLevelUpDone,
                  ),
                ),
              ),
            ),
          ),
        // 도전과제 토스트
        if (_showingAchievement && _achievementQueue.isNotEmpty)
          Positioned(
            top: MediaQuery.of(context).padding.top + kToolbarHeight + 12,
            left: 0,
            right: 0,
            child: AchievementToast(
              key: ValueKey(_achievementQueue.first.id),
              achievement: _achievementQueue.first,
              onDone: _onAchievementToastDone,
            ),
          ),
      ],
    );
  }

  Widget _buildHome(ThemeData theme) {
    final streak =
        ref.watch(streakProvider).valueOrNull ?? JackpotStreakData.empty;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: _showLanding
          ? Landing(
              key: const ValueKey('landing'),
              loading: _loading,
              spinTurns: _spinController,
              previewImageUrls: (_todayRule?.targets ?? const [])
                  .map((t) => t.imageUrl)
                  .whereType<String>()
                  .where((u) => u.trim().isNotEmpty)
                  .toList(),
              onQuickStart: () async {
                _haptic(HapticFeedback.mediumImpact);
                setState(() => _showLanding = false);
                await _runDraw(showPopup: true);
              },
              onOpenCount: () {
                _haptic(HapticFeedback.selectionClick);
                setState(() => _showLanding = false);
                _openCountSheet();
              },
              statBar: Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (streak.streak > 0) _buildStreakChip(theme, streak),
                  BossCountdownWidget(count: _count),
                ],
              ),
              footer: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 18,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '비공식 팬 프로젝트입니다. Konami 및 Yu-Gi-Oh!와 무관합니다.\n'
                            '카드 데이터/이미지: Yu-Gi-Oh! API by YGOPRODeck',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          : LayoutBuilder(
              key: const ValueKey('main'),
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 480;
                final hp = compact ? 12.0 : 16.0;
                return Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        hp,
                        compact ? 4 : 10,
                        hp,
                        compact ? 4 : 4,
                      ),
                      child: SlotHeader(
                        rule: _todayRule,
                        count: _count,
                        compact: compact,
                        onTapExactTarget: _openExactTargetPreview,
                      ),
                    ),
                    // 오늘의 현황: 스트릭/위클리챌린지/보스데이/모드/배틀을
                    // 가로 스크롤 한 줄로 묶어 세로 공간을 아끼고 그리드에 집중시킨다.
                    Padding(
                      padding: EdgeInsets.fromLTRB(hp, 0, 0, compact ? 4 : 8),
                      child: _buildStatusStrip(theme, streak, hp),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: _ClimaxFlash(
                        animation: _climaxFlashController,
                        child: DrawBoard(
                          cards: _cards,
                          loading: _loading,
                          error: _error,
                          hasGenerated: _hasGenerated,
                          spinning: _spinning,
                          stopped: _stopped,
                          reelNotifier: _reelNotifier,
                          scrollController: _gridScrollController,
                          todayRule: _todayRule,
                          isBossJackpot: _isBossJackpot,
                          spinController: _spinController,
                          count: _count,
                          onRetry: () {
                            setState(() => _error = null);
                            _runDraw(showPopup: true);
                          },
                          onCardTap: _showCardDetail,
                          spotlightIndex: _spotlightIndex,
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    // 엄지로 누르기 편하도록 그리드 아래에 배치: compact는 뽑기 + 연속뽑기 한 행, wide는 별도 행
                    if (compact)
                      Padding(
                        padding: EdgeInsets.fromLTRB(hp, 8, hp, 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: (_loading || _batch.running)
                                    ? null
                                    : () async {
                                        _haptic(HapticFeedback.mediumImpact);
                                        await _runDraw(showPopup: true);
                                      },
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 3,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    RotationTransition(
                                      turns: _spinning
                                          ? _spinController
                                          : const AlwaysStoppedAnimation(0),
                                      child: const Icon(Icons.casino, size: 14),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _loading
                                          ? AppStrings.drawingButton
                                          : AppStrings.drawButton,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            OutlinedButton(
                              onPressed: _loading
                                  ? null
                                  : _batch.running
                                  ? _stopBatchDraw
                                  : _openBatchPicker,
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 3,
                                  horizontal: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                foregroundColor: _batch.running
                                    ? theme.colorScheme.error
                                    : theme.colorScheme.onSurfaceVariant,
                                side: _batch.running
                                    ? BorderSide(
                                        color: theme.colorScheme.error
                                            .withAlpha(160),
                                      )
                                    : null,
                              ),
                              child: _batch.running
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.stop_circle_outlined,
                                          size: 13,
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          '${_batch.done}/${_batch.total}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    )
                                  : const Icon(Icons.repeat, size: 15),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      Padding(
                        padding: EdgeInsets.fromLTRB(hp, 12, hp, 10),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: (_loading || _batch.running)
                                ? null
                                : () async {
                                    _haptic(HapticFeedback.mediumImpact);
                                    await _runDraw(showPopup: true);
                                  },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                RotationTransition(
                                  turns: _spinning
                                      ? _spinController
                                      : const AlwaysStoppedAnimation(0),
                                  child: const Icon(Icons.casino),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  _loading
                                      ? AppStrings.drawingButton
                                      : AppStrings.drawButton,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(hp, 0, hp, 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _loading
                                    ? null
                                    : _batch.running
                                    ? _stopBatchDraw
                                    : _openBatchPicker,
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 11,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  foregroundColor: _batch.running
                                      ? theme.colorScheme.error
                                      : theme.colorScheme.onSurfaceVariant,
                                  side: _batch.running
                                      ? BorderSide(
                                          color: theme.colorScheme.error
                                              .withAlpha(160),
                                        )
                                      : null,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _batch.running
                                          ? Icons.stop_circle_outlined
                                          : Icons.repeat,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _batch.running
                                          ? AppStrings.batchStopButton
                                          : AppStrings.batchStartButton,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (_batch.running) ...[
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      theme.colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: theme.dividerColor),
                                ),
                                child: Text(
                                  '${_batch.done} / ${_batch.total}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                    if (_batch.running && _batch.total > 0)
                      LinearProgressIndicator(
                        value: _batch.done / _batch.total,
                        minHeight: 2,
                        borderRadius: BorderRadius.zero,
                      ),
                  ],
                );
              },
            ),
    );
  }

  /// 스트릭/위클리챌린지/보스데이/모드/배틀을 한 줄로 모은 가로 스크롤 현황 스트립.
  /// 세로로 쌓이던 정보 박스들을 한데 묶어 카드 그리드가 화면의 주인공이 되도록 한다.
  Widget _buildStatusStrip(
    ThemeData theme,
    JackpotStreakData streak,
    double hp,
  ) {
    final canOpenCount = !(_loading || _batch.running);
    final showBattle = _hasGenerated && !_spinning && _cards.isNotEmpty;
    final pity = ref.watch(targetPityProvider).valueOrNull;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.only(right: hp),
      child: Row(
        children: [
          WeeklyChallengeWidget(
            cards: _hasGenerated && !_spinning ? _cards : null,
            compact: true,
          ),
          if (pity != null && pity.missCount > 0) ...[
            const SizedBox(width: 8),
            _buildPityChip(theme, pity),
          ],
          if (streak.streak > 0) ...[
            const SizedBox(width: 8),
            _buildStreakChip(theme, streak),
          ],
          const SizedBox(width: 8),
          BossCountdownWidget(count: _count),
          const SizedBox(width: 8),
          _buildModeChip(theme, onTap: canOpenCount ? _openCountSheet : null),
          if (showBattle) ...[
            const SizedBox(width: 8),
            _buildBattleChip(theme),
          ],
        ],
      ),
    );
  }

  /// 천장 진행도 칩. 미스 횟수가 소프트 천장에 가까워질수록 골드로 강조된다.
  Widget _buildPityChip(ThemeData theme, TargetPityState pity) {
    final isClose = pity.missCount >= kPitySoftStart;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: isClose
            ? AppColors.gold.withAlpha(40)
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isClose ? AppColors.gold.withAlpha(180) : theme.dividerColor,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🎯', style: TextStyle(fontSize: 13)),
          const SizedBox(width: 6),
          Text(
            '천장 ${pity.missCount}/$kPityHard',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: isClose ? AppColors.goldDark : theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeChip(ThemeData theme, {VoidCallback? onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.tune,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              '모드: ${_currentFilterSummary()}',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.expand_more,
              size: 14,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBattleChip(ThemeData theme) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: _openBattle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withAlpha(120),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: theme.colorScheme.primary.withAlpha(120)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.sports_martial_arts,
              size: 16,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Text(
              '배틀',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreakChip(ThemeData theme, JackpotStreakData streakData) {
    final streak = streakData.streak;
    if (streak <= 0) return const SizedBox.shrink();

    final isDone = streakData.todayDone;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _PulseGlow(
        key: ValueKey('streak_$streak$isDone'),
        active: isDone,
        color: AppColors.gold,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: isDone
                ? AppColors.gold.withAlpha(40)
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isDone
                  ? AppColors.gold.withAlpha(180)
                  : theme.dividerColor,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isDone ? '🔥 $streak일 연속 잭팟 달성! 🏆' : '🔥 $streak일 연속 중… 오늘도?',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: isDone
                      ? AppColors.goldDark
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (streakData.best > 1) ...[
                const SizedBox(width: 8),
                Text(
                  '최고 ${streakData.best}일',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _openCountSheet() {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: false,
      showDragHandle: true,
      builder: (_) => CountPickerSheet(
        initialCount: _count,
        onApply: (newCount) {
          setState(() {
            _count = newCount;
            _todayRule = null;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _ensureTodayRuleFromDailyPool();
          });
        },
      ),
    );
  }
}

/// 달성 상태를 강조하는 은은한 펄스 글로우.
/// active가 false면 child를 그대로 통과시켜 평소엔 비용이 들지 않는다.
class _PulseGlow extends StatefulWidget {
  final bool active;
  final Color color;
  final BorderRadius borderRadius;
  final Widget child;

  const _PulseGlow({
    super.key,
    required this.active,
    required this.color,
    required this.borderRadius,
    required this.child,
  });

  @override
  State<_PulseGlow> createState() => _PulseGlowState();
}

class _PulseGlowState extends State<_PulseGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (widget.active) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _PulseGlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active != oldWidget.active) {
      if (widget.active) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
        _controller.value = 0;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            boxShadow: [
              BoxShadow(
                color: widget.color.withAlpha((50 + 60 * t).round()),
                blurRadius: 6 + 10 * t,
                spreadRadius: 1 + 2 * t,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// 마지막 릴이 멈추는 순간 보드 전체에 입히는 짧은 완성 클라이맥스 연출.
/// 살짝 확대되었다가 제자리로 돌아오는 스케일 펄스와 옅은 화이트 플래시를 겹쳐
/// "결과가 공개됐다"는 임팩트를 더한다. 보스 잭팟 전용 골드 플래시(_flashController)와는
/// 별개로, 결과에 상관없이 매 회차 완성 시점에 항상 재생된다.
class _ClimaxFlash extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;

  const _ClimaxFlash({required this.animation, required this.child});

  @override
  Widget build(BuildContext context) {
    // child(DrawBoard)는 LayoutBuilder/AnimatedSwitcher/GridView를 품고 있어
    // 매 프레임 다시 빌드/변환하면 레이아웃 재진입 충돌이 난다.
    // 그래서 child는 그대로 두고, 플래시 오버레이만 별도 레이어로 얹는다.
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: animation,
              builder: (context, _) {
                final t = animation.value;
                final flashOpacity =
                    (t < 0.15 ? t / 0.15 : (1.0 - t) / 0.85).clamp(0.0, 1.0) * 0.3;
                return Opacity(
                  opacity: flashOpacity,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(color: Colors.white),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
