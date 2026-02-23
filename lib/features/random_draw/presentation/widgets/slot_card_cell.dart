import 'package:flutter/material.dart';

import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/ygo_card_back.dart';
import '../slot_ui/slot_ui_helpers.dart';

class SlotCardCell extends StatelessWidget {
  final String title;
  final String? imageUrl;
  final bool isExact;
  final VoidCallback? onTapPreview;
  final SlotDifficulty? difficulty;

  const SlotCardCell({
    super.key,
    required this.title,
    this.imageUrl,
    this.isExact = false,
    this.onTapPreview,
    this.difficulty,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasImage = (imageUrl ?? '').trim().isNotEmpty;

    return SizedBox(
      height: 62,
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
              fit: StackFit.expand,
              children: [
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
                          aspectRatio: 59 / 86,
                          child: Transform.scale(
                            scale: 1.15,
                            child: AppNetworkImage(
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
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 6),
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
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 160),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            title,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.visible,
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
                ),
                if (difficulty != null)
                  Positioned(
                    left: 6,
                    top: 6,
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
                if (isExact && onTapPreview != null)
                  Positioned(
                    right: 6,
                    top: 6,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
