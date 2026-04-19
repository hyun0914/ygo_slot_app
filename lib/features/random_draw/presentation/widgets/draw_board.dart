import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../../core/app_constants.dart';
import '../../../../../core/app_strings.dart';
import '../../../../../core/models/ygopro_card.dart';
import '../../domain/daily_slot_rule.dart';
import 'card_tile.dart';
import 'skeleton.dart';

class DrawBoard extends StatelessWidget {
  final List<YgoCard> cards;
  final bool loading;
  final String? error;
  final bool hasGenerated;
  final bool spinning;
  final Set<int> stopped;
  final ValueNotifier<List<int>> reelNotifier;
  final ScrollController scrollController;
  final DailySlotRule? todayRule;
  final bool isBossJackpot;
  final AnimationController spinController;
  final int count;
  final VoidCallback onRetry;
  final void Function(YgoCard card) onCardTap;

  const DrawBoard({
    super.key,
    required this.cards,
    required this.loading,
    required this.error,
    required this.hasGenerated,
    required this.spinning,
    required this.stopped,
    required this.reelNotifier,
    required this.scrollController,
    required this.todayRule,
    required this.isBossJackpot,
    required this.spinController,
    required this.count,
    required this.onRetry,
    required this.onCardTap,
  });

  int _gridColumnCount(double maxWidth) {
    if (maxWidth < 320) return 2;
    if (maxWidth < 480) return 3;
    if (maxWidth < 720) return 4;
    if (maxWidth < 1024) return 5;
    if (maxWidth < 1280) return 6;
    return 7;
  }

  ({int cols, double aspectRatio, bool scrollable}) _calcGridLayout(
    double width,
    double height,
    int count,
  ) {
    const spacing = 12.0;
    const minCardWidth = 90.0;

    if (count <= 0) {
      return (cols: 1, aspectRatio: AppConstants.ygoCardAspectRatio, scrollable: false);
    }

    if (height.isInfinite || height <= 0) {
      final cols = min(count, _gridColumnCount(width));
      return (cols: cols, aspectRatio: AppConstants.ygoCardAspectRatio, scrollable: true);
    }

    for (int cols = 1; cols <= count; cols++) {
      final cardW = (width - spacing * (cols - 1)) / cols;
      if (cardW < minCardWidth) break;

      final rows = (count / cols).ceil();
      final cardH = cardW / AppConstants.ygoCardAspectRatio;
      final totalH = rows * cardH + spacing * (rows - 1);

      if (totalH <= height) {
        final idealH = (height - spacing * (rows - 1)) / rows;
        final ar = (cardW / idealH).clamp(0.5, AppConstants.ygoCardAspectRatio);
        return (cols: cols, aspectRatio: ar, scrollable: false);
      }
    }

    final cols = min(count, _gridColumnCount(width));
    return (cols: cols, aspectRatio: AppConstants.ygoCardAspectRatio, scrollable: true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Widget child;

    if (error != null) {
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
                error!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
              ),
              const SizedBox(height: 16),
              FilledButton.tonal(onPressed: onRetry, child: const Text(AppStrings.retryButton)),
            ],
          ),
        ),
      );
    } else if (!hasGenerated) {
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
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      );
    } else if (loading && cards.isEmpty) {
      child = Padding(
        key: const ValueKey('skeleton'),
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(builder: (context, c) {
          return SkeletonGrid(
            crossAxisCount: min(count, _gridColumnCount(c.maxWidth)),
            itemCount: count,
          );
        }),
      );
    } else if (cards.isEmpty) {
      child = Center(
        key: const ValueKey('empty'),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off, size: 48,
                  color: theme.colorScheme.onSurfaceVariant.withAlpha(160)),
              const SizedBox(height: 12),
              Text(AppStrings.emptyCardMessage,
                  textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: loading ? null : onRetry,
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
        child: LayoutBuilder(builder: (context, c) {
          final layout = _calcGridLayout(c.maxWidth, c.maxHeight, cards.length);

          return RepaintBoundary(
            child: ValueListenableBuilder<List<int>>(
              valueListenable: reelNotifier,
              builder: (context, reelIndex, _) {
                return GridView.builder(
                  controller: scrollController,
                  physics: layout.scrollable ? null : const NeverScrollableScrollPhysics(),
                  itemCount: cards.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: layout.cols,
                    childAspectRatio: layout.aspectRatio,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemBuilder: (context, i) {
                    final finalCard = cards[i];
                    final spinningThisCard = spinning && !stopped.contains(i);

                    YgoCard displayCard = finalCard;
                    YgoCard nextDisplayCard = finalCard;

                    if (spinningThisCard &&
                        reelIndex.isNotEmpty &&
                        reelIndex.length == cards.length) {
                      final idx = reelIndex[i];
                      final nextIdx = (idx + 1) % cards.length;
                      displayCard = cards[idx];
                      nextDisplayCard = cards[nextIdx];
                    }

                    return CardTile(
                      key: ValueKey(finalCard.id),
                      finalCard: finalCard,
                      displayCard: displayCard,
                      nextDisplayCard: nextDisplayCard,
                      onTap: spinningThisCard ? () {} : () => onCardTap(finalCard),
                      spinning: spinningThisCard,
                      pulse: spinController,
                      isJackpotHit: isBossJackpot &&
                          (todayRule?.targets.any((t) => t.cardId == finalCard.id) ?? false),
                    );
                  },
                );
              },
            ),
          );
        }),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: child,
    );
  }
}
