import 'package:flutter/material.dart';

import '../../../../core/models/ygopro_card.dart';

import 'reel_strip.dart';

class CardTile extends StatelessWidget {
  final YgoCard finalCard;
  final YgoCard displayCard;
  final YgoCard nextDisplayCard;

  final VoidCallback onTap;
  final bool spinning;
  final Animation<double> pulse;

  const CardTile({
    super.key,
    required this.finalCard,
    required this.displayCard,
    required this.nextDisplayCard,
    required this.onTap,
    required this.spinning,
    required this.pulse,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: ClipRect(
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                theme.colorScheme.surfaceContainerHighest,
                                theme.colorScheme.surface,
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: Center(
                          child: AspectRatio(
                            aspectRatio: 59 / 86,
                            child: ReelStrip(
                              spinning: spinning,
                              pulse: pulse,
                              currentUrl: displayCard.imageUrl,
                              nextUrl: nextDisplayCard.imageUrl,
                            ),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: AnimatedOpacity(
                            opacity: spinning ? 1 : 0,
                            duration: const Duration(milliseconds: 120),
                            child: AnimatedBuilder(
                              animation: pulse,
                              builder: (_, _) {
                                final p = (pulse.value * 6) % 1;
                                final a = (50 + (p * 120)).toInt();
                                return DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        theme.colorScheme.primary.withAlpha(a),
                                        Colors.transparent,
                                        theme.colorScheme.secondary.withAlpha(a),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: SizedBox(
                  height: 40,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        height: 20,
                        child: FittedBox(
                          alignment: Alignment.centerLeft,
                          fit: BoxFit.scaleDown,
                          child: Text(
                            finalCard.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      SizedBox(
                        height: 16,
                        child: FittedBox(
                          alignment: Alignment.centerLeft,
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _subInfo(finalCard),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _subInfo(YgoCard c) {
    final parts = <String>[];
    if (c.attribute != null) parts.add(c.attribute!.toUpperCase());
    if (c.race != null) parts.add(c.race!);
    if (c.level != null) parts.add('Lv ${c.level}');
    if (c.atk != null || c.def != null) {
      parts.add('ATK ${c.atk ?? '-'} / DEF ${c.def ?? '-'}');
    }
    return parts.join(' • ');
  }
}