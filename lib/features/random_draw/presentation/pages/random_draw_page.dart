import 'dart:async';
import 'dart:math';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/api_client.dart';
import '../../../../core/models/ygopro_card.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/ygo_card_back.dart';
import '../../application/random_draw_controller.dart';
import '../../domain/draw_filter.dart';
import '../../domain/daily_slot_rule.dart';
import '../widgets/landing.dart';
import '../widgets/slot_header.dart';
import '../widgets/slot_result_dialog.dart';
import '../widgets/card_tile.dart';
import '../widgets/skeleton.dart';

// -----------------------------
// Page
// -----------------------------
class RandomDrawPage extends StatefulWidget {
  const RandomDrawPage({super.key});

  @override
  State<RandomDrawPage> createState() => _RandomDrawPageState();
}

class _RandomDrawPageState extends State<RandomDrawPage> with SingleTickerProviderStateMixin {
  late final RandomDrawController _controller;

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

  // 릴
  Timer? _reelTimer;
  List<int> _reelIndex = [];

  // 스크롤
  final ScrollController _gridScrollController = ScrollController();

  // util
  final Random _random = Random();

  // 오늘 룰 (exact/category)
  DailySlotRule? _todayRule;

  // Draw 완료를 “진짜 끝까지” 기다리기 위한 completer
  Completer<void>? _drawCompleter;

  // 연속뽑기(배치)
  bool _batchRunning = false;
  int _batchToken = 0; // 취소 토큰
  int _batchTotal = 0;
  int _batchDone = 0;
  final Map<int, int> _batchHist = {0: 0, 1: 0, 2: 0, 3: 0};

  // 데일리 룰 전용 풀(뽑기 결과와 분리)
  List<YgoCard> _dailyPool = [];
  String? _dailyPoolDateKey; // yyyy-MM-dd
  Future<void>? _dailyPoolFuture; // 동시 호출 방지(중복 네트워크 방지)

  static const _kTodayRuleKeyPrefix = 'random_draw_today_rule_v1';

  String _todayRulePrefsKey(int count) => '${_kTodayRuleKeyPrefix}_$count';

  @override
  void initState() {
    super.initState();
    _controller = RandomDrawController(YgoApiClient());

    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadTodayRuleFromPrefs(count: _count);
      if (!mounted) return;
      if (_todayRule == null) {
        await _ensureTodayRuleFromDailyPool();
      }
    });
  }

  @override
  void dispose() {
    _finishTimer?.cancel();
    _reelTimer?.cancel();
    _gridScrollController.dispose();
    _spinController.dispose();
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
        return '도전(3장)';
      case 5:
        return '기본(5장)';
      case 7:
        return '편안(7장)';
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
    await _loadTodayRuleFromPrefs(count: count);
    if (_todayRule != null && _todayRule!.dateKey == key) return;

    await _ensureDailyPool();
    _todayRule = buildTodayRule(_dailyPool, now: DateTime.now(), count: count);

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
    });

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

      _reelIndex = List<int>.generate(result.length, (_) => 0);

      _reelTimer = Timer.periodic(const Duration(milliseconds: 55), (_) {
        if (!mounted) return;
        if (!_spinning) return;
        if (_cards.isEmpty) return;

        setState(() {
          for (var i = 0; i < _cards.length; i++) {
            if (_stopped.contains(i)) continue;
            _reelIndex[i] = (_reelIndex[i] + 1) % _cards.length;
          }
        });
      });

      _finishOrder = List<int>.generate(result.length, (i) => i)..shuffle(_random);

      _haptic(HapticFeedback.mediumImpact);

      var cursor = 0;

      _finishTimer = Timer.periodic(const Duration(milliseconds: 90), (t) {
        if (!mounted) return;

        final idx = _finishOrder[cursor];
        setState(() => _stopped.add(idx));
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
                duration: const Duration(milliseconds: 260),
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
      setState(() => _error = e.toString());
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

    if (!showPopup) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final hits = countSlotHits(cards: _cards, rule: _todayRule);
      if (hits > 0) {
        _showSingleHitPopup(hits);
      }
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
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
    if (_batchRunning) return;

    setState(() {
      _batchRunning = true;
      _batchTotal = total;
      _batchDone = 0;
      _batchHist[0] = 0;
      _batchHist[1] = 0;
      _batchHist[2] = 0;
      _batchHist[3] = 0;
    });

    final token = ++_batchToken;

    for (var i = 0; i < total; i++) {
      if (!mounted) break;
      if (token != _batchToken) break;

      await _runDraw(showPopup: false);

      if (!mounted) break;
      if (token != _batchToken) break;

      final hits = countSlotHits(cards: _cards, rule: _todayRule).clamp(0, 3);
      _batchHist[hits] = (_batchHist[hits] ?? 0) + 1;

      setState(() => _batchDone = i + 1);

      await Future.delayed(const Duration(milliseconds: 140));
    }

    if (!mounted) return;
    final cancelled = token != _batchToken;

    setState(() => _batchRunning = false);

    if (cancelled) return;
    _showBatchSummaryPopup();
  }

  void _stopBatchDraw() {
    _batchToken++;
    if (mounted) setState(() => _batchRunning = false);
  }

  // -----------------------------
  // Popups
  // -----------------------------
  void _showSingleHitPopup(int hits) {
    final rule = _todayRule;
    if (rule == null) return;

    final title = hits >= 3
        ? '🎰 잭팟!'
        : hits == 2
        ? '🔥 2개 적중!'
        : '✨ 1개 적중!';

    final message = hits >= 3
        ? '오늘의 타겟 3개 전부 맞췄어요!'
        : hits == 2
        ? '거의 잭팟… 한 번만 더!'
        : '적중! 운이 달아오르는 중 🔥';

    showDialog(
      context: context,
      builder: (_) => SlotResultDialog(
        hits: hits,
        targets: 3,
        title: title,
        message: message,
        rule: rule,
        cards: _cards,
      ),
    );
  }

  void _showBatchSummaryPopup() {
    final total = _batchTotal;
    final zero = _batchHist[0] ?? 0;
    final one = _batchHist[1] ?? 0;
    final two = _batchHist[2] ?? 0;
    final three = _batchHist[3] ?? 0;

    final jackpotRate = total == 0 ? 0.0 : (three / total) * 100.0;
    final hitRate = total == 0 ? 0.0 : ((total - zero) / total) * 100.0;

    showDialog(
      context: context,
      builder: (_) {
        final theme = Theme.of(context);
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text('🔁 연속 뽑기 결과',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('총 $total회',
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              _resultLine(theme, '0개 적중', '$zero'),
              _resultLine(theme, '1개 적중', '$one'),
              _resultLine(theme, '2개 적중', '$two'),
              _resultLine(theme, '3개(잭팟)', '$three'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('🎰 잭팟률: ${jackpotRate.toStringAsFixed(1)}%',
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text('✨ (참고) 1개 이상 적중률: ${hitRate.toStringAsFixed(1)}%',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                  ],
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
      },
    );
  }

  Widget _resultLine(ThemeData theme, String left, String right) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(left, style: theme.textTheme.bodyMedium)),
          Text(right,
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900)),
        ],
      ),
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
    } catch (_) {}
  }

  // -----------------------------
  // Daily pool & prefs
  // -----------------------------
  Future<void> _ensureDailyPool() async {
    final key = _todayKey(DateTime.now());

    if (_dailyPoolDateKey == key && _dailyPool.isNotEmpty) return;

    if (_dailyPoolFuture != null) {
      await _dailyPoolFuture;
      return;
    }

    _dailyPoolFuture = () async {
      _dailyPoolDateKey = key;
      _dailyPool = [];

      const tries = [200, 120, 80, 50];

      for (final n in tries) {
        try {
          final pool = await _controller.generateDraw(
            DrawFilter(
              count: n,
              type: null,
              attribute: null,
              levelExpr: null,
              atkExpr: null,
            ),
          );

          if (pool.isNotEmpty) {
            _dailyPool = pool;
            break;
          }
        } catch (_) {}
      }
    }();

    try {
      await _dailyPoolFuture;
    } finally {
      _dailyPoolFuture = null;
    }
  }

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
        final t = e as Map<String, dynamic>;
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
    }catch (_) {
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
                          aspectRatio: 59 / 86,
                          child: AppNetworkImage(
                            url,
                            fit: BoxFit.contain,
                            fallback: (_) => const YgoCardBack(label: 'YGO'),
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

    return Scaffold(
      appBar: AppBar(title: const Text('유희왕 슬롯')),
      body: SafeArea(child: _buildHome(theme)),
    );
  }

  Widget _buildHome(ThemeData theme) {
    if (_showLanding) {
      return Landing(
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
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: SlotHeader(
            rule: _todayRule,
            count: _count,
            onTapExactTarget: _openExactTargetPreview,
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
                onPressed: _loading || _batchRunning ? null : _openCountSheet,
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
              onPressed: (_loading || _batchRunning)
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
                    _loading ? '🎲 뽑는 중...' : '🎲 랜덤 뽑기',
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
                      : _batchRunning
                      ? _stopBatchDraw
                      : _openBatchPicker,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    foregroundColor: theme.colorScheme.onSurfaceVariant,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_batchRunning ? Icons.stop_circle_outlined : Icons.repeat, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        _batchRunning ? '연속뽑기 중단' : '연속 뽑기',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
              ),
              if (_batchRunning) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: theme.dividerColor),
                  ),
                  child: Text(
                    '$_batchDone / $_batchTotal',
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
        const Divider(height: 1),
        Expanded(child: _buildBoard(theme)),
      ],
    );
  }

  Widget _buildBoard(ThemeData theme) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '에러: $_error',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ),
      );
    }

    if (!_hasGenerated) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '버튼 한 번 누르고\n뭐 나오는지 보자 😎',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      );
    }

    if (_loading && _cards.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, c) {
            var crossAxisCount = 5;
            if (c.maxWidth < 400) {
              crossAxisCount = 2;
            } else if (c.maxWidth < 700) {
              crossAxisCount = 3;
            }
            else if (c.maxWidth < 1000) {
              crossAxisCount = 4;
            }
            return SkeletonGrid(crossAxisCount: crossAxisCount);
          },
        ),
      );
    }

    if (_cards.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '카드가 없어요.\n다시 뽑아볼까요?',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, c) {
          var crossAxisCount = 5;
          if (c.maxWidth < 400) {
            crossAxisCount = 2;
          }
          else if (c.maxWidth < 700) {
            crossAxisCount = 3;
          }
          else if (c.maxWidth < 1000) {
            crossAxisCount = 4;
          }

          return GridView.builder(
            controller: _gridScrollController,
            itemCount: _cards.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: 0.7,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemBuilder: (context, i) {
              final finalCard = _cards[i];
              final spinningThisCard = _spinning && !_stopped.contains(i);

              YgoCard displayCard = finalCard;
              YgoCard nextDisplayCard = finalCard;

              if (spinningThisCard &&
                  _reelIndex.isNotEmpty &&
                  _reelIndex.length == _cards.length &&
                  _cards.isNotEmpty) {
                final idx = _reelIndex[i];
                final nextIdx = (idx + 1) % _cards.length;
                displayCard = _cards[idx];
                nextDisplayCard = _cards[nextIdx];
              }

              return CardTile(
                key: ValueKey(finalCard.id),
                finalCard: finalCard,
                displayCard: displayCard,
                nextDisplayCard: nextDisplayCard,
                onTap: () {},
                spinning: spinningThisCard,
                pulse: _spinController,
              );
            },
          );
        },
      ),
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
                      '모드 선택',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '카드 수를 고정 모드로 단순화했어. (3/5/7)',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    modeCard(
                      title: '도전 모드 (3장)',
                      desc: '짧고 날카롭게. 잭팟이 진짜 어렵다 🔥',
                      value: 3,
                      icon: Icons.whatshot,
                    ),
                    const SizedBox(height: 10),
                    modeCard(
                      title: '기본 모드 (5장)',
                      desc: '지금 너가 말한 “제일 맛있는 밸런스” 🎰',
                      value: 5,
                      icon: Icons.casino,
                    ),
                    const SizedBox(height: 10),
                    modeCard(
                      title: '편안 모드 (7장)',
                      desc: '조금 더 자주 맞추고 싶은 날 🏆',
                      value: 7,
                      icon: Icons.emoji_events,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => setSheetState(() => tCount = 5),
                            child: const Text('기본(5)로'),
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
