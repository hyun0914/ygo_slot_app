import 'package:flutter/material.dart';

import '../../../../core/app_constants.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/ygo_card_back.dart';
import '../../application/draw_history_store.dart';
import '../../domain/draw_history_entry.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<DrawHistoryEntry> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await DrawHistoryStore.loadAll();
    if (!mounted) return;
    setState(() {
      _entries = all;
      _loading = false;
    });
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('기록 전체 삭제'),
        content: const Text('뽑기 기록을 모두 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await DrawHistoryStore.clear();
    if (!mounted) return;
    setState(() => _entries = []);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('뽑기 기록'),
        actions: [
          if (_entries.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: '전체 삭제',
              onPressed: _clearAll,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? _buildEmpty(theme)
              : _buildList(theme),
    );
  }

  Widget _buildEmpty(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.history,
            size: 56,
            color: theme.colorScheme.onSurfaceVariant.withAlpha(100),
          ),
          const SizedBox(height: 16),
          Text(
            '아직 뽑기 기록이 없어요',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '메인 화면에서 뽑기를 해보세요!',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(ThemeData theme) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _HistoryTile(entry: _entries[i]),
    );
  }
}

// ─────────────────────────────────────────
// 히스토리 타일
// ─────────────────────────────────────────
class _HistoryTile extends StatelessWidget {
  final DrawHistoryEntry entry;
  const _HistoryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            _buildThumbnails(theme),
            const SizedBox(width: 12),
            Expanded(child: _buildInfo(theme)),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnails(ThemeData theme) {
    const thumbW = 36.0;
    const thumbH = thumbW / AppConstants.ygoCardAspectRatio;
    const maxShow = 3;

    final showCount = entry.cards.length.clamp(0, maxShow);
    final overflow = entry.cards.length - maxShow;

    return SizedBox(
      width: maxShow * thumbW + (maxShow - 1) * 4.0,
      height: thumbH,
      child: Stack(
        children: [
          ...List.generate(showCount, (i) {
            final card = entry.cards[i];
            return Positioned(
              left: i * (thumbW + 4),
              top: 0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  width: thumbW,
                  height: thumbH,
                  child: card.imageUrl.isNotEmpty
                      ? AppNetworkImage(
                          card.imageUrl,
                          fit: BoxFit.cover,
                          fallback: (_) => const YgoCardBack(label: 'YGO'),
                        )
                      : const YgoCardBack(label: 'YGO'),
                ),
              ),
            );
          }),
          if (overflow > 0)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withAlpha(220),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '+$overflow',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfo(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _formatDate(entry.timestamp),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            _HitsBadge(hits: entry.hits, theme: theme),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${entry.mode}장 모드',
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateUtils.dateOnly(now);
    final yesterday = today.subtract(const Duration(days: 1));
    final day = DateUtils.dateOnly(dt);

    final hhmm =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    if (day == today) return '오늘 $hhmm';
    if (day == yesterday) return '어제 $hhmm';
    return '${dt.month}월 ${dt.day}일 $hhmm';
  }
}

// ─────────────────────────────────────────
// 적중 수 배지
// ─────────────────────────────────────────
class _HitsBadge extends StatelessWidget {
  final int hits;
  final ThemeData theme;
  const _HitsBadge({required this.hits, required this.theme});

  static const _kGold = Color(0xFFFFD700);

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (hits) {
      >= 3 => ('🏆 잭팟', _kGold.withAlpha(40), const Color(0xFFB8860B)),
      2 => ('🔥 2적중', theme.colorScheme.secondaryContainer,
          theme.colorScheme.onSecondaryContainer),
      1 => ('✨ 1적중', theme.colorScheme.tertiaryContainer,
          theme.colorScheme.onTertiaryContainer),
      _ => ('− 미적중', theme.colorScheme.surfaceContainerHighest,
          theme.colorScheme.onSurfaceVariant),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: hits >= 3
            ? Border.all(color: _kGold.withAlpha(160))
            : null,
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w900,
          color: fg,
        ),
      ),
    );
  }
}
