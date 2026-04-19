import 'dart:async';
import 'dart:math';
import 'dart:convert';

import 'package:confetti/confetti.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/api_client.dart';
import '../../../../core/app_constants.dart';
import '../../../../core/app_strings.dart';
import '../../../../core/models/ygopro_card.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/cloud_sync_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/share_service.dart';
import '../../../../core/services/sound_service.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/ygo_card_back.dart';
import '../../../achievements/application/achievement_store.dart';
import '../../../favorites/application/favorites_store.dart';
import '../../../favorites/presentation/pages/favorites_page.dart';
import '../../../stats/presentation/pages/stats_page.dart';
import '../../../achievements/domain/achievement.dart';
import '../../../achievements/presentation/pages/achievements_page.dart';
import '../../../battle/presentation/pages/battle_page.dart';
import '../../../collection/application/collection_store.dart';
import '../../../collection/presentation/pages/collection_page.dart';
import '../../../level/application/level_store.dart';
import '../../../level/domain/level_config.dart';
import '../../../level/presentation/widgets/level_badge.dart';
import '../../../level/presentation/widgets/level_up_overlay.dart';
import '../../../weekly_challenge/application/weekly_challenge_store.dart';
import '../../../weekly_challenge/domain/weekly_challenge.dart';
import '../../../weekly_challenge/presentation/widgets/weekly_challenge_widget.dart';
import '../../application/draw_history_store.dart';
import '../../application/draw_stats_store.dart';
import '../../application/play_log_store.dart';
import '../../application/random_draw_controller.dart';
import '../../domain/draw_filter.dart';
import '../../domain/daily_slot_rule.dart';
import '../../domain/draw_history_entry.dart';
import '../widgets/boss_countdown_widget.dart';
import '../widgets/landing.dart';
import '../widgets/streak_calendar_widget.dart';
import 'history_page.dart';
import 'probability_page.dart';
import '../widgets/slot_header.dart';
import '../widgets/slot_result_dialog.dart';
import '../widgets/card_tile.dart';
import '../widgets/skeleton.dart';

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
class RandomDrawPage extends StatefulWidget {
  const RandomDrawPage({super.key});

  @override
  State<RandomDrawPage> createState() => _RandomDrawPageState();
}

class _RandomDrawPageState extends State<RandomDrawPage> with TickerProviderStateMixin {
  late final RandomDrawController _controller;

  // Confetti
  late final ConfettiController _confettiController;
  late final ConfettiController _confettiBossLeft;
  late final ConfettiController _confettiBossRight;

  // 보스 잭팟 연출
  late final AnimationController _flashController;
  late final AnimationController _bossTextController;
  bool _isBossJackpot = false;

  // 잭팟 스트릭
  int _jackpotStreak = 0;
  int _bestJackpotStreak = 0;
  int _totalJackpots = 0;
  bool _todayJackpotDone = false;

  // 통계 / 컬렉션
  int _totalDraws = 0;
  int _collectionSize = 0;

  // 도전과제 토스트 큐
  final List<Achievement> _achievementQueue = [];
  bool _showingAchievement = false;
  // 배치 중 누적된 도전과제 (배치 완료 후 표시)
  final List<Achievement> _pendingBatchAchievements = [];

  // 레벨 / XP
  int _currentXp = 0;

  // 레벨업 오버레이 큐
  final List<int> _levelUpQueue = [];
  bool _showingLevelUp = false;

  // 위클리 챌린지
  late WeeklyChallengeDef _weeklyChallenge;

  // 즐겨찾기
  Set<int> _favoriteIds = {};

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

  // SharedPreferences 키 버전 정책:
  // - 저장 포맷(JSON 구조)이 바뀔 경우 v2, v3... 으로 올린다.
  // - 버전을 올리면 구버전 키는 자동으로 무시된다(날짜 불일치로 삭제됨).
  // - 강제 삭제가 필요하면 initState에서 prefs.remove(구버전 키) 를 호출한다.
  static const _kTodayRuleKeyPrefix = 'random_draw_today_rule_v1';
  static const _kStreakKey = 'ygo_jackpot_streak_v1';

  String _todayRulePrefsKey(int count) => '${_kTodayRuleKeyPrefix}_$count';

  String _friendlyError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('timeout') || msg.contains('timedout')) {
      return '네트워크 응답이 너무 느립니다.\n잠시 후 다시 시도해 주세요.';
    }
    if (msg.contains('socketexception') || msg.contains('network') || msg.contains('connection')) {
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

    _confettiController = ConfettiController(duration: const Duration(seconds: 4));
    _confettiBossLeft  = ConfettiController(duration: const Duration(seconds: 5));
    _confettiBossRight = ConfettiController(duration: const Duration(seconds: 5));
    _flashController   = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _bossTextController= AnimationController(vsync: this, duration: const Duration(milliseconds: 2500));

    _weeklyChallenge = pickWeeklyChallenge(now: DateTime.now());

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadTodayRuleFromPrefs(count: _count);
      if (!mounted) return;
      if (_todayRule == null) {
        await _ensureTodayRuleFromDailyPool();
      }
      await _loadStreak();
      _totalDraws = await DrawStatsStore.getTotalDraws();
      final col = await CollectionStore.loadAll();
      final xp = await LevelStore.getTotalXp();
      final favIds = await FavoritesStore.loadIds();
      if (mounted) {
        setState(() {
          _collectionSize = col.length;
          _currentXp = xp;
          _favoriteIds = favIds;
        });
      }
      // 로그인 직후 클라우드 데이터가 아직 반영 안 됐을 수 있으므로 sync 후 재로드
      await CloudSyncService.downloadAndMerge();
      if (!mounted) return;
      final syncedXp = await LevelStore.getTotalXp();
      final syncedCol = await CollectionStore.loadAll();
      final syncedFavIds = await FavoritesStore.loadIds();
      if (mounted) {
        setState(() {
          _currentXp = syncedXp;
          _collectionSize = syncedCol.length;
          _favoriteIds = syncedFavIds;
        });
      }
      // 알림: 오늘 아직 안 뽑았으면 브라우저 알림
      if (NotificationService.isSupported) {
        final playLog = await PlayLogStore.load();
        final todayStr = _todayKey(DateTime.now());
        final playedToday = playLog.playDates.contains(todayStr);
        await NotificationService.showIfNotPlayedToday(playedToday: playedToday);
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

    // 모드별 키로 로드
    debugPrint('[TodayRule] 캐시 미스 — prefs 로드 시도 (count=$count, date=$key)');
    await _loadTodayRuleFromPrefs(count: count);
    if (_todayRule != null && _todayRule!.dateKey == key) {
      debugPrint('[TodayRule] prefs에서 복원 성공 (kind=${_todayRule!.kind.name})');
      return;
    }

    final dailyPool = await _controller.ensureDailyPool();
    debugPrint('[TodayRule] 풀 크기: ${dailyPool.length}, 새 룰 생성 중...');
    _todayRule = buildTodayRule(dailyPool, now: DateTime.now(), count: count);
    debugPrint('[TodayRule] 생성 완료 — kind=${_todayRule!.kind.name}');

    // 모드별 키로 저장
    await _saveTodayRuleToPrefs(_todayRule!, count: count);

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
      final result = await _controller.generateDraw(filter);
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

      _finishOrder = List<int>.generate(result.length, (i) => i)..shuffle(_random);

      _haptic(HapticFeedback.mediumImpact);

      var cursor = 0;

      _finishTimer = Timer.periodic(AppConstants.reelStopInterval, (t) {
        if (!mounted) return;

        final idx = _finishOrder[cursor];
        setState(() => _stopped.add(idx));
        SoundService.playReelTick();
        _haptic(HapticFeedback.selectionClick);

        cursor++;
        if (cursor >= _finishOrder.length) {
          t.cancel();
          _finishTimer = null;

          _haptic(HapticFeedback.mediumImpact);
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
        }
      });
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
        if (hits > 0) _showSingleHitPopup(hits);
        _saveDrawHistory(hits);
      }

      await _onDrawComplete(hits, isBatch: !showPopup);
    });
  }

  // -----------------------------
  // Batch Draw (5/10/15)
  // -----------------------------
  void _openBatchPicker() {
    if (_loading || _spinning) return;

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
              16, 12, 16,
              MediaQuery.viewInsetsOf(ctx).bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('연속 뽑기',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                Text('정해진 횟수만큼만 돌리고, 마지막에 요약 결과를 보여줘요.',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _batchChoice(ctx, 5)),
                    const SizedBox(width: 10),
                    Expanded(child: _batchChoice(ctx, 10)),
                    const SizedBox(width: 10),
                    Expanded(child: _batchChoice(ctx, 15)),
                  ],
                ),
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

  Widget _batchChoice(BuildContext ctx, int n) {
    return ElevatedButton(
      onPressed: () {
        Navigator.of(ctx).pop();
        _startBatch(n);
      },
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Text('$n회', style: const TextStyle(fontWeight: FontWeight.w900)),
    );
  }

  Future<void> _startBatch(int total) async {
    if (_batch.running) return;

    setState(() => _batch.reset(total));

    final token = ++_batch.token;

    for (var i = 0; i < total; i++) {
      if (!mounted) break;
      if (token != _batch.token) break;

      await _runDraw(showPopup: false);

      if (!mounted) break;
      if (token != _batch.token) break;

      final hits = countSlotHits(cards: _cards, rule: _todayRule).clamp(0, 3);
      _batch.hist[hits] = (_batch.hist[hits] ?? 0) + 1;

      if (hits >= 3) {
        if (_todayRule?.kind == DayKind.boss) {
          unawaited(_triggerBossJackpot());
        } else {
          _confettiController.play();
        }
        await _updateStreak();
      }

      setState(() => _batch.done = i + 1);

      await Future.delayed(AppConstants.batchDrawDelay);
    }

    if (!mounted) return;
    final cancelled = token != _batch.token;

    setState(() => _batch.running = false);

    if (cancelled) return;

    // 배치 완료 후 레벨업 + 도전과제 표시
    if (_levelUpQueue.isNotEmpty) _processLevelUpQueue();
    if (_pendingBatchAchievements.isNotEmpty) {
      _achievementQueue.addAll(_pendingBatchAchievements);
      _pendingBatchAchievements.clear();
      _processAchievementQueue();
    }

    CloudSyncService.uploadAfterDraw();
    _showBatchSummaryPopup();
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
      _updateStreak();
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
        final scale = CurvedAnimation(parent: animation, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: Tween<double>(begin: beginScale, end: 1.0).animate(scale),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
    );
  }

  void _showBatchSummaryPopup() {
    final total = _batch.total;
    final zero = _batch.hist[0] ?? 0;
    final one = _batch.hist[1] ?? 0;
    final two = _batch.hist[2] ?? 0;
    final three = _batch.hist[3] ?? 0;

    final jackpotRate = total == 0 ? 0.0 : (three / total) * 100.0;
    final hitRate = total == 0 ? 0.0 : ((total - zero) / total) * 100.0;

    final hasJackpot = three > 0;
    final streakAtClose = _jackpotStreak;
    final bestAtClose = _bestJackpotStreak;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (ctx, anim, secAnim) {
        final theme = Theme.of(context);
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: hasJackpot
                ? const BorderSide(color: Color(0xFFFFD700), width: 2)
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
              _resultBar(theme, '0개 적중', zero, total,
                  theme.colorScheme.onSurfaceVariant.withAlpha(100)),
              const SizedBox(height: 6),
              _resultBar(theme, '1개 적중', one, total, theme.colorScheme.secondary),
              const SizedBox(height: 6),
              _resultBar(theme, '2개 적중', two, total, theme.colorScheme.tertiary),
              const SizedBox(height: 6),
              _resultBar(theme, '3개(잭팟)', three, total,
                  hasJackpot ? const Color(0xFFFFD700) : theme.colorScheme.primary),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: hasJackpot
                      ? const Color(0xFFFFD700).withAlpha(20)
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: hasJackpot
                        ? const Color(0xFFFFD700).withAlpha(160)
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
                        color: hasJackpot ? const Color(0xFFB8860B) : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('✨ (참고) 1개 이상 적중률: ${hitRate.toStringAsFixed(1)}%',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              if (hasJackpot && streakAtClose > 0) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700).withAlpha(28),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFD700).withAlpha(140)),
                  ),
                  child: Text(
                    '🔥 $streakAtClose일 연속 잭팟 달성 중!'
                    '${bestAtClose > 1 ? '  최고 $bestAtClose일' : ''}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFFB8860B),
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
      },
      transitionBuilder: (ctx, animation, secAnim, child) {
        final scale = CurvedAnimation(parent: animation, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.75, end: 1.0).animate(scale),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
    );
  }

  Widget _resultBar(ThemeData theme, String label, int count, int total, Color barColor) {
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
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
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
          .map((c) => DrawHistoryCard(id: c.id, name: c.name, imageUrl: c.imageUrl))
          .toList(),
    );
    DrawHistoryStore.addEntry(entry); // fire-and-forget
  }

  Future<void> _onDrawComplete(int hits, {required bool isBatch}) async {
    if (_cards.isEmpty) return;

    // 컬렉션 업데이트
    final newSize = await CollectionStore.addCards(
      _cards.map((c) => (id: c.id, name: c.name, imageUrl: c.imageUrl)).toList(),
    );

    // 총 뽑기 횟수
    final newDraws = await DrawStatsStore.increment();

    // 플레이 로그 (잭팟 여부)
    final isJackpot = hits >= 3;
    await PlayLogStore.recordPlay(jackpot: isJackpot);

    // 도전과제 체크
    final event = AchievementEvent(
      drew: true,
      hitOccurred: hits > 0,
      jackpot: isJackpot,
      bossJackpot: isJackpot && _todayRule?.kind == DayKind.boss,
      mode: _count,
      isBatch: isBatch,
      currentStreak: _jackpotStreak,
      totalJackpots: _totalJackpots,
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
    final lvResult = await LevelStore.addXp(xpGain);

    // 위클리 챌린지 완료 체크
    if (_weeklyChallenge.isCompleted(_cards)) {
      await WeeklyChallengeStore.recordCompletion();
    }

    if (!mounted) return;
    setState(() {
      _totalDraws = newDraws;
      _collectionSize = newSize;
      _currentXp = lvResult.xp;
    });
    debugPrint('[Stats] 총 뽑기: $_totalDraws회, 도감: $_collectionSize종, Lv.${lvResult.level}');

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
    final isNow = await FavoritesStore.toggle(cardId);
    if (!mounted) return;
    setState(() {
      if (isNow) {
        _favoriteIds.add(cardId);
      } else {
        _favoriteIds.remove(cardId);
      }
    });
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
    final dayType = rule?.kind == DayKind.boss
        ? '👑 보스데이'
        : rule?.kind == DayKind.spotlight
            ? '✨ 스포트라이트'
            : '🎯 일반';
    final hitEmoji = hits >= 3 ? '🎰 잭팟!' : hits == 2 ? '🔥 2히트' : hits == 1 ? '✨ 1히트' : '💨 미스';
    final cardNames = _cards.take(3).map((c) => c.name).join(', ');
    final text =
        '유희왕 슬롯 결과\n'
        '$dayType | $hitEmoji\n'
        '뽑은 카드: $cardNames${_cards.length > 3 ? ' 외 ${_cards.length - 3}장' : ''}\n'
        '🔥 연속 잭팟: $_jackpotStreak일';
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
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final favNow = _favoriteIds.contains(card.id);
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: AppNetworkImage(
                          card.imageUrl,
                          width: 80,
                          height: 116,
                          fit: BoxFit.cover,
                          fallback: (_) => const YgoCardBack(label: 'YGO'),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(card.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            if (card.attribute != null) _infoRow('속성', card.attribute!),
                            if (card.race != null) _infoRow('종족', card.race!),
                            if (card.level != null) _infoRow('레벨', '${card.level}'),
                            if (card.atk != null || card.def != null)
                              _infoRow('ATK/DEF', '${card.atk ?? "-"} / ${card.def ?? "-"}'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (card.desc.isNotEmpty)
                    Text(
                      card.desc,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await _toggleFavorite(card.id);
                            setSheet(() {});
                          },
                          icon: Icon(favNow ? Icons.bookmark : Icons.bookmark_border, size: 18),
                          label: Text(favNow ? '즐겨찾기 해제' : '즐겨찾기'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            _shareResult(countSlotHits(cards: _cards, rule: _todayRule));
                          },
                          icon: const Icon(Icons.share, size: 18),
                          label: const Text('결과 공유'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          Text(value, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  void _openNotificationSettings() {
    if (!NotificationService.isSupported) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('이 브라우저는 알림을 지원하지 않습니다'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => _NotificationSettingsDialog(),
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

  void _openHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const HistoryPage()),
    );
  }

  // -----------------------------
  // Jackpot streak
  // -----------------------------
  Future<void> _loadStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kStreakKey);
    if (raw == null || raw.isEmpty) return;

    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final lastDate = (m['lastDate'] as String?) ?? '';
      final streak = (m['streak'] as num?)?.toInt() ?? 0;
      final best = (m['best'] as num?)?.toInt() ?? 0;
      final total = (m['total'] as num?)?.toInt() ?? 0;

      final today = _todayKey(DateTime.now());
      final yesterday = _todayKey(DateTime.now().subtract(const Duration(days: 1)));

      if (!mounted) return;
      setState(() {
        _totalJackpots = total;
        _bestJackpotStreak = best;
        if (lastDate == today) {
          _jackpotStreak = streak;
          _todayJackpotDone = true;
        } else if (lastDate == yesterday) {
          _jackpotStreak = streak;
          _todayJackpotDone = false;
        } else {
          // 연속이 끊겼으므로 스트릭 리셋
          _jackpotStreak = 0;
          _todayJackpotDone = false;
        }
      });
    } catch (e) {
      debugPrint('[Streak] 파싱 실패: $e');
    }
  }

  Future<void> _updateStreak() async {
    if (_todayJackpotDone) return;

    final today = _todayKey(DateTime.now());
    final yesterday = _todayKey(DateTime.now().subtract(const Duration(days: 1)));

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kStreakKey);

    String lastDate = '';
    int streak = 0;
    int best = _bestJackpotStreak;
    int total = _totalJackpots;

    if (raw != null && raw.isNotEmpty) {
      try {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        lastDate = (m['lastDate'] as String?) ?? '';
        streak = (m['streak'] as num?)?.toInt() ?? 0;
        best = (m['best'] as num?)?.toInt() ?? _bestJackpotStreak;
        total = (m['total'] as num?)?.toInt() ?? _totalJackpots;
      } catch (_) {}
    }

    if (lastDate == today) {
      // 오늘 이미 저장됨 (다른 경로로 호출된 경우 방어)
      if (!mounted) return;
      setState(() => _todayJackpotDone = true);
      return;
    } else if (lastDate == yesterday) {
      streak++;
    } else {
      streak = 1;
    }

    total++;
    if (streak > best) best = streak;

    final m = <String, dynamic>{
      'lastDate': today,
      'streak': streak,
      'best': best,
      'total': total,
    };
    await prefs.setString(_kStreakKey, jsonEncode(m));

    if (!mounted) return;
    setState(() {
      _jackpotStreak = streak;
      _bestJackpotStreak = best;
      _totalJackpots = total;
      _todayJackpotDone = true;
    });
  }

  // -----------------------------
  // Daily pool & prefs
  Future<void> _loadTodayRuleFromPrefs({required int count}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_todayRulePrefsKey(count));
    if (raw == null || raw.isEmpty) return;

    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;

      final todayKey = _todayKey(DateTime.now());
      final dateKey = (m['dateKey'] as String?) ?? '';
      if (dateKey != todayKey) {
        await prefs.remove(_todayRulePrefsKey(count));
        return;
      }

      final kindStr = (m['kind'] as String?) ?? 'normal';
      final kind = switch (kindStr) {
        'boss' => DayKind.boss,
        'spotlight' => DayKind.spotlight,
        _ => DayKind.normal,
      };

      final list = (m['targets'] as List?) ?? const [];
      final targets = list.map((e) {
        if (e is! Map<String, dynamic>) return SlotTarget.category('');
        final t = e;
        final cardId = (t['cardId'] as num?)?.toInt();
        if (cardId != null && cardId > 0) {
          return SlotTarget.exact(
            cardId,
            cardName: t['cardName'] as String?,
            imageUrl: t['imageUrl'] as String?,
          );
        }
        return SlotTarget.category((t['category'] as String?) ?? '');
      }).toList();

      if (targets.length != 3) return;

      _todayRule = DailySlotRule(dateKey: dateKey, kind: kind, targets: targets);
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('[TodayRule] 파싱 실패, 저장된 데이터 삭제: $e');
      await prefs.remove(_todayRulePrefsKey(count));
    }
  }

  Future<void> _saveTodayRuleToPrefs(DailySlotRule rule, {required int count}) async {
    final prefs = await SharedPreferences.getInstance();

    final m = <String, dynamic>{
      'dateKey': rule.dateKey,
      'kind': switch (rule.kind) {
        DayKind.normal => 'normal',
        DayKind.spotlight => 'spotlight',
        DayKind.boss => 'boss',
      },
      'targets': rule.targets.map((t) {
        if (t.cardId != null) {
          return {'cardId': t.cardId, 'cardName': t.cardName, 'imageUrl': t.imageUrl};
        }
        return {'category': t.category};
      }).toList(),
    };

    await prefs.setString(_todayRulePrefsKey(count), jsonEncode(m));
  }

  void _openExactTargetPreview(SlotTarget t) {
    final url = (t.imageUrl ?? '').trim();
    if (url.isEmpty) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final size = MediaQuery.of(ctx).size;

        final cardWidth = (size.width * 0.52).clamp(180.0, 260.0);

        const sidePad = 16.0;
        const extraSpace = 14.0;

        final dialogWidth =
        (cardWidth + (sidePad * 2) + (extraSpace * 2)).clamp(0.0, size.width - 32);

        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: SizedBox(
            width: dialogWidth,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Container(
                color: theme.colorScheme.surface,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            t.cardName ?? '카드 미리보기',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: const Icon(Icons.close),
                          tooltip: '닫기',
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: extraSpace),
                      child: SizedBox(
                        width: cardWidth,
                        child: AspectRatio(
                          aspectRatio: AppConstants.ygoCardAspectRatio,
                          child: Hero(
                            tag: 'slot_card_${t.cardId}',
                            child: AppNetworkImage(
                              url,
                              fit: BoxFit.contain,
                              fallback: (_) => const YgoCardBack(label: 'YGO'),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(Icons.check),
                        label: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Text('확인'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // -----------------------------
  // UI
  // -----------------------------
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text('유희왕 슬롯'),
            actions: [
              // 레벨 배지
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: LevelBadge(xp: _currentXp, compact: true),
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
              PopupMenuButton<String>(
                icon: const Icon(Icons.menu),
                tooltip: '더 보기',
                onSelected: (v) async {
                  if (v == 'achievement') {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AchievementsPage()));
                  } else if (v == 'collection') {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CollectionPage()));
                  } else if (v == 'favorites') {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FavoritesPage()));
                  } else if (v == 'stats') {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StatsPage()));
                  } else if (v == 'history') {
                    _openHistory();
                  } else if (v == 'probability') {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProbabilityPage()));
                  } else if (v == 'notification') {
                    _openNotificationSettings();
                  } else if (v == 'sync') {
                    final messenger = ScaffoldMessenger.of(context);
                    await CloudSyncService.uploadAll();
                    messenger.showSnackBar(
                      const SnackBar(content: Text('클라우드에 저장했습니다.')),
                    );
                  } else if (v == 'logout') {
                    await AuthService.signOut();
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'achievement', child: Row(children: [Text('🏆', style: TextStyle(fontSize: 16)), SizedBox(width: 8), Text('도전과제')])),
                  const PopupMenuItem(value: 'collection',  child: Row(children: [Text('📚', style: TextStyle(fontSize: 16)), SizedBox(width: 8), Text('카드 도감')])),
                  const PopupMenuItem(value: 'favorites',   child: Row(children: [Text('🔖', style: TextStyle(fontSize: 16)), SizedBox(width: 8), Text('즐겨찾기')])),
                  const PopupMenuItem(value: 'stats',       child: Row(children: [Text('📈', style: TextStyle(fontSize: 16)), SizedBox(width: 8), Text('통계')])),
                  const PopupMenuItem(value: 'history',     child: Row(children: [Text('📋', style: TextStyle(fontSize: 16)), SizedBox(width: 8), Text('뽑기 기록')])),
                  const PopupMenuItem(value: 'probability', child: Row(children: [Text('📊', style: TextStyle(fontSize: 16)), SizedBox(width: 8), Text('확률 정보')])),
                  const PopupMenuItem(value: 'notification',child: Row(children: [Text('🔔', style: TextStyle(fontSize: 16)), SizedBox(width: 8), Text('알림 설정')])),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'account_info',
                    enabled: false,
                    child: Row(children: [
                      const Icon(Icons.account_circle, size: 16),
                      const SizedBox(width: 8),
                      Flexible(child: Text(
                        AuthService.nickname ?? AuthService.currentUser?.email ?? '',
                        style: const TextStyle(fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      )),
                    ]),
                  ),
                  const PopupMenuItem(value: 'sync',   child: Row(children: [Icon(Icons.cloud_upload, size: 16), SizedBox(width: 8), Text('클라우드 저장')])),
                  const PopupMenuItem(value: 'logout', child: Row(children: [Icon(Icons.logout, size: 16), SizedBox(width: 8), Text('로그아웃')])),
                ],
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
                Color(0xFFFFD700),
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
                child: Container(color: const Color(0xFFFFD700)),
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
              final opacity = (t < 0.1
                  ? t / 0.1
                  : t > 0.7
                  ? (1.0 - t) / 0.3
                  : 1.0).clamp(0.0, 1.0);
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
                        color: Color(0xFFFFD700),
                        letterSpacing: 2,
                        shadows: [
                          Shadow(color: Colors.black87, blurRadius: 16, offset: Offset(0, 4)),
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
              colors: const [Color(0xFFFFD700), Colors.orange, Colors.red, Colors.white],
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
              colors: const [Color(0xFFFFD700), Colors.orange, Colors.red, Colors.white],
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
              footer: Column(
                children: [
                  if (_jackpotStreak > 0) ...[
                    const SizedBox(height: 14),
                    _buildStreakChip(theme),
                  ],
                  const SizedBox(height: 10),
                  BossCountdownWidget(count: _count),
                  const SizedBox(height: 14),
                  const StreakCalendarWidget(),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline,
                            size: 18, color: theme.colorScheme.onSurfaceVariant),
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
          : Column(
              key: const ValueKey('main'),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: SlotHeader(
            rule: _todayRule,
            count: _count,
            onTapExactTarget: _openExactTargetPreview,
          ),
        ),
        if (_jackpotStreak > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: _buildStreakChip(theme),
          ),
        // 위클리 챌린지
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
          child: WeeklyChallengeWidget(
            cards: _hasGenerated && !_spinning ? _cards : null,
          ),
        ),
        // 보스데이 카운트다운 + 배틀 버튼 행
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
          child: Row(
            children: [
              BossCountdownWidget(count: _count),
              const Spacer(),
              if (_hasGenerated && !_spinning && _cards.isNotEmpty)
                TextButton.icon(
                  onPressed: _openBattle,
                  icon: const Icon(Icons.sports_martial_arts, size: 16),
                  label: const Text('배틀'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.tune, size: 16, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Text(
                      '모드: ${_currentFilterSummary()}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _loading || _batch.running ? null : _openCountSheet,
                icon: const Icon(Icons.settings, size: 18),
                label: const Text('변경'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
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
                    turns: _spinning ? _spinController : const AlwaysStoppedAnimation(0),
                    child: const Icon(Icons.casino),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _loading ? AppStrings.drawingButton : AppStrings.drawButton,
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
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
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
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    foregroundColor: _batch.running
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurfaceVariant,
                    side: _batch.running
                        ? BorderSide(color: theme.colorScheme.error.withAlpha(160))
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_batch.running ? Icons.stop_circle_outlined : Icons.repeat, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        _batch.running ? AppStrings.batchStopButton : AppStrings.batchStartButton,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
              ),
              if (_batch.running) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
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
        if (_batch.running && _batch.total > 0)
          LinearProgressIndicator(
            value: _batch.done / _batch.total,
            minHeight: 2,
            borderRadius: BorderRadius.zero,
          ),
        const Divider(height: 1),
        Expanded(child: _buildBoard(theme)),
      ],
    ),
    );
  }

  Widget _buildStreakChip(ThemeData theme) {
    if (_jackpotStreak <= 0) return const SizedBox.shrink();

    final isDone = _todayJackpotDone;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Container(
        key: ValueKey('streak_$_jackpotStreak$isDone'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isDone
              ? const Color(0xFFFFD700).withAlpha(40)
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isDone
                ? const Color(0xFFFFD700).withAlpha(180)
                : theme.dividerColor,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isDone
                  ? '🔥 $_jackpotStreak일 연속 잭팟 달성! 🏆'
                  : '🔥 $_jackpotStreak일 연속 중… 오늘도?',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: isDone
                    ? const Color(0xFFB8860B)
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (_bestJackpotStreak > 1) ...[
              const SizedBox(width: 8),
              Text(
                '최고 $_bestJackpotStreak일',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 화면 너비만으로 열 수 결정 (스켈레톤 / 폴백용)
  int _gridColumnCount(double maxWidth) {
    if (maxWidth < 320) return 2;
    if (maxWidth < 480) return 3;
    if (maxWidth < 720) return 4;
    if (maxWidth < 1024) return 5;
    if (maxWidth < 1280) return 6;
    return 7;
  }

  /// 너비·높이·카드 수를 함께 고려해 최적 그리드 레이아웃을 계산합니다.
  ///
  /// - [cols]: 열 수 (항상 카드 수 이하 → 오른쪽 빈 여백 없음)
  /// - [aspectRatio]: childAspectRatio (가용 높이를 꽉 채우도록 조정)
  /// - [scrollable]: 콘텐츠가 가용 높이를 초과하면 true
  ({int cols, double aspectRatio, bool scrollable}) _calcGridLayout(
    double width,
    double height,
    int count,
  ) {
    const spacing = 12.0;
    const minCardWidth = 90.0; // 이보다 좁으면 글자/이미지 판독 불가

    if (count <= 0) {
      return (cols: 1, aspectRatio: AppConstants.ygoCardAspectRatio, scrollable: false);
    }

    // 높이가 무한(unbounded)이면 너비 기반 폴백 사용
    if (height.isInfinite || height <= 0) {
      final cols = min(count, _gridColumnCount(width));
      return (cols: cols, aspectRatio: AppConstants.ygoCardAspectRatio, scrollable: true);
    }

    // cols=1 → count 방향으로 늘리면서 모든 행이 가용 높이에 들어오는 최소 열 수 탐색
    for (int cols = 1; cols <= count; cols++) {
      final cardW = (width - spacing * (cols - 1)) / cols;
      if (cardW < minCardWidth) break; // 너무 좁아지면 중단 → 폴백

      final rows = (count / cols).ceil();
      final cardH = cardW / AppConstants.ygoCardAspectRatio;
      final totalH = rows * cardH + spacing * (rows - 1);

      if (totalH <= height) {
        // 자연 비율로도 들어감 → 남은 세로 공간을 채우도록 비율 조정
        final idealH = (height - spacing * (rows - 1)) / rows;
        // 카드가 자연 비율보다 더 세로로 길어지지 않도록 하한 클램프
        final ar = (cardW / idealH).clamp(0.5, AppConstants.ygoCardAspectRatio);
        return (cols: cols, aspectRatio: ar, scrollable: false);
      }
    }

    // 어떤 열 수로도 스크롤 없이 불가능 → 너비 기반, 오른쪽 여백만 제거
    final cols = min(count, _gridColumnCount(width));
    return (cols: cols, aspectRatio: AppConstants.ygoCardAspectRatio, scrollable: true);
  }

  Widget _buildBoard(ThemeData theme) {
    final Widget child;

    if (_error != null) {
      child = Center(
        key: const ValueKey('error'),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: () {
                  setState(() => _error = null);
                  _runDraw(showPopup: true);
                },
                child: const Text(AppStrings.retryButton),
              ),
            ],
          ),
        ),
      );
    } else if (!_hasGenerated) {
      child = Center(
        key: const ValueKey('initial'),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.casino_outlined, size: 52, color: theme.colorScheme.primary.withAlpha(160)),
              const SizedBox(height: 16),
              Text(
                AppStrings.initialPrompt,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      );
    } else if (_loading && _cards.isEmpty) {
      child = Padding(
        key: const ValueKey('skeleton'),
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, c) {
            return SkeletonGrid(
              crossAxisCount: min(_count, _gridColumnCount(c.maxWidth)),
              itemCount: _count,
            );
          },
        ),
      );
    } else if (_cards.isEmpty) {
      child = Center(
        key: const ValueKey('empty'),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off, size: 48, color: theme.colorScheme.onSurfaceVariant.withAlpha(160)),
              const SizedBox(height: 12),
              Text(
                AppStrings.emptyCardMessage,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: _loading ? null : () => _runDraw(showPopup: true),
                child: const Text(AppStrings.redrawButton),
              ),
            ],
          ),
        ),
      );
    } else {
      child = Padding(
        key: const ValueKey('grid'),
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, c) {
            final layout = _calcGridLayout(c.maxWidth, c.maxHeight, _cards.length);

            return RepaintBoundary(
              child: ValueListenableBuilder<List<int>>(
                valueListenable: _reelNotifier,
                builder: (context, reelIndex, _) {
                  return GridView.builder(
                    controller: _gridScrollController,
                    physics: layout.scrollable
                        ? null
                        : const NeverScrollableScrollPhysics(),
                    itemCount: _cards.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: layout.cols,
                      childAspectRatio: layout.aspectRatio,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemBuilder: (context, i) {
                      final finalCard = _cards[i];
                      final spinningThisCard = _spinning && !_stopped.contains(i);

                      YgoCard displayCard = finalCard;
                      YgoCard nextDisplayCard = finalCard;

                      if (spinningThisCard &&
                          reelIndex.isNotEmpty &&
                          reelIndex.length == _cards.length &&
                          _cards.isNotEmpty) {
                        final idx = reelIndex[i];
                        final nextIdx = (idx + 1) % _cards.length;
                        displayCard = _cards[idx];
                        nextDisplayCard = _cards[nextIdx];
                      }

                      return CardTile(
                        key: ValueKey(finalCard.id),
                        finalCard: finalCard,
                        displayCard: displayCard,
                        nextDisplayCard: nextDisplayCard,
                        onTap: spinningThisCard ? () {} : () => _showCardDetail(finalCard),
                        spinning: spinningThisCard,
                        pulse: _spinController,
                        isJackpotHit: _isBossJackpot &&
                            (_todayRule?.targets.any((t) => t.cardId == finalCard.id) ?? false),
                      );
                    },
                  );
                },
              ),
            );
          },
        ),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: child,
    );
  }

  void _openCountSheet() {
    int tCount = _count;
    if (tCount != 3 && tCount != 5 && tCount != 7) tCount = 5;

    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: false,
      showDragHandle: true,
      builder: (sheetCtx) {
        final theme = Theme.of(sheetCtx);

        return StatefulBuilder(
          builder: (context, setSheetState) {
            Widget modeCard({
              required String title,
              required String desc,
              required int value,
              required IconData icon,
            }) {
              final selected = tCount == value;

              return Material(
                color: selected ? theme.colorScheme.primary.withAlpha(16) : theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => setSheetState(() => tCount = value),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: selected
                            ? theme.colorScheme.primary.withAlpha(140)
                            : theme.dividerColor,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: selected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            icon,
                            color: selected
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                desc,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: selected ? theme.colorScheme.primary : Colors.transparent,
                            border: Border.all(
                              color: selected ? theme.colorScheme.primary : theme.dividerColor,
                              width: 2,
                            ),
                          ),
                          child: selected
                              ? Icon(Icons.check, size: 14, color: theme.colorScheme.onPrimary)
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            void applyAndClose() {
              setState(() {
                _count = tCount;
                _todayRule = null; // 모드 바뀌면 룰 무효화해서 헤더/타겟 동기화
              });

              Navigator.of(sheetCtx).pop();

              // 다음 프레임에 모드 기준으로 룰 생성/로드
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                _ensureTodayRuleFromDailyPool();
              });
            }

            return SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  10,
                  16,
                  16 + MediaQuery.of(sheetCtx).padding.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.modePickerTitle,
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      AppStrings.modePickerSubtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    modeCard(
                      title: AppStrings.modeChallengeTitle,
                      desc: AppStrings.modeChallengeDesc,
                      value: 3,
                      icon: Icons.whatshot,
                    ),
                    const SizedBox(height: 10),
                    modeCard(
                      title: AppStrings.modeDefaultTitle,
                      desc: AppStrings.modeDefaultDesc,
                      value: 5,
                      icon: Icons.casino,
                    ),
                    const SizedBox(height: 10),
                    modeCard(
                      title: AppStrings.modeComfortTitle,
                      desc: AppStrings.modeComfortDesc,
                      value: 7,
                      icon: Icons.emoji_events,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => setSheetState(() => tCount = 5),
                            child: const Text(AppStrings.modeResetButton),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: applyAndClose,
                            child: const Text('적용'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ──────────────────────────────────────────────
// 알림 설정 다이얼로그
// ──────────────────────────────────────────────
class _NotificationSettingsDialog extends StatefulWidget {
  @override
  State<_NotificationSettingsDialog> createState() =>
      _NotificationSettingsDialogState();
}

class _NotificationSettingsDialogState
    extends State<_NotificationSettingsDialog> {
  String _permission = 'default';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadPermission();
  }

  Future<void> _loadPermission() async {
    final p = await NotificationService.getPermission();
    if (mounted) setState(() => _permission = p);
  }

  Future<void> _request() async {
    setState(() => _loading = true);
    final granted = await NotificationService.requestPermission();
    if (mounted) {
      setState(() {
        _permission = granted ? 'granted' : 'denied';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final (permLabel, permColor, permEmoji) = switch (_permission) {
      'granted' => ('허용됨', Colors.green, '✅'),
      'denied'  => ('거부됨', theme.colorScheme.error, '❌'),
      _         => ('미설정', theme.colorScheme.onSurfaceVariant, '❓'),
    };

    return AlertDialog(
      title: const Text('🔔 알림 설정'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '오늘 뽑기를 잊지 않도록 브라우저 알림을 받을 수 있습니다.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text('현재 상태: $permEmoji ', style: theme.textTheme.bodyMedium),
              Text(permLabel,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: permColor,
                    fontWeight: FontWeight.bold,
                  )),
            ],
          ),
          if (_permission != 'granted') ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _request,
                child: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('알림 허용하기'),
              ),
            ),
          ],
          if (_permission == 'granted') ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => NotificationService.show(
                  '🎴 테스트 알림',
                  body: '알림이 정상적으로 작동합니다!',
                ),
                icon: const Icon(Icons.notifications_active, size: 18),
                label: const Text('테스트 알림 보내기'),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('닫기'),
        ),
      ],
    );
  }
}
