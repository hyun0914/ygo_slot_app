import 'package:flutter/material.dart';

import '../../../../core/app_constants.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/ygo_card_back.dart';
import '../slot_ui/slot_ui_helpers.dart';

class SlotCardCell extends StatelessWidget {
  final String title;
  final String? imageUrl;
  final bool isExact;
  final VoidCallback? onTapPreview;
  final SlotDifficulty? difficulty;
  final Object? heroTag;

  const SlotCardCell({
    super.key,
    required this.title,
    this.imageUrl,
    this.isExact = false,
    this.onTapPreview,
    this.difficulty,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasImage = (imageUrl ?? '').trim().isNotEmpty;

    return Semantics(
      button: onTapPreview != null,
      label: isExact ? '카드: $title (탭하면 크게 보기)' : '타겟: $title',
      child: Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTapPreview,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            // passthrough: 부모 constraints를 그대로 자식에게 전달
            // 첫 번째 비positioned 자식(SizedBox)이 Stack의 최소 크기를 결정함
            fit: StackFit.passthrough,
            children: [
              // Stack 크기 기준 자식: 최소 높이 62px, 너비는 부모에 맞춤
              const SizedBox(height: 62, width: double.infinity),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    border: Border.all(color: theme.dividerColor.withAlpha(200)),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 10,
                        spreadRadius: 0,
                        color: theme.colorScheme.primary.withAlpha(20),
                      ),
                    ],
                  ),
                ),
              ),
              if (isExact && hasImage)
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(6, 4, 6, 2),
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: AppConstants.ygoCardAspectRatio,
                        child: Transform.scale(
                          scale: 1.15,
                          child: heroTag != null
                              ? Hero(
                                  tag: heroTag!,
                                  child: AppNetworkImage(
                                    imageUrl!.trim(),
                                    fit: BoxFit.contain,
                                    fallback: (_) => const YgoCardBack(label: 'YGO'),
                                  ),
                                )
                              : AppNetworkImage(
                                  imageUrl!.trim(),
                                  fit: BoxFit.contain,
                                  fallback: (_) => const YgoCardBack(label: 'YGO'),
                                ),
                        ),
                      ),
                    ),
                  ),
                )
              else
                Positioned.fill(
                  child: Center(
                    child: Transform.scale(
                      scale: 1.06,
                      child: const YgoCardBack(label: 'YGO'),
                    ),
                  ),
                ),
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          theme.colorScheme.surface.withAlpha(140),
                          Colors.transparent,
                          Colors.transparent,
                          theme.colorScheme.surface.withAlpha(90),
                        ],
                        stops: const [0.0, 0.25, 0.75, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
              // 타이틀 칩: Positioned.fill + Align 으로 감싸서 Stack 크기에 영향 없이 하단 정렬
              Positioned.fill(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface.withAlpha(235),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: theme.dividerColor.withAlpha(200)),
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 8,
                            spreadRadius: 0,
                            color: theme.colorScheme.primary.withAlpha(18),
                          ),
                        ],
                      ),
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (difficulty != null)
                Positioned(
                  left: 6,
                  top: 6,
                  child: Tooltip(
                    message: _difficultyLabel(difficulty!),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface.withAlpha(220),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      child: Text(
                        difficultyBadgeText(difficulty!),
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ),
                ),
              if (isExact && onTapPreview != null)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Tooltip(
                    message: '카드 크게 보기',
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface.withAlpha(220),
                        shape: BoxShape.circle,
                        border: Border.all(color: theme.dividerColor),
                      ),
                      child: Icon(Icons.zoom_in, size: 16, color: theme.colorScheme.onSurface),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  String _difficultyLabel(SlotDifficulty d) {
    switch (d) {
      case SlotDifficulty.easy:
        return '난이도: 쉬움';
      case SlotDifficulty.medium:
        return '난이도: 보통';
      case SlotDifficulty.hard:
        return '난이도: 어려움';
    }
  }
}
