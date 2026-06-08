import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../core/app_colors.dart';
import '../../../../core/app_constants.dart';
import '../../../../core/models/ygopro_card.dart';

import 'reel_strip.dart';

class CardTile extends StatefulWidget {
  final YgoCard finalCard;
  final YgoCard displayCard;
  final YgoCard nextDisplayCard;

  final VoidCallback onTap;
  final bool spinning;
  final Animation<double> pulse;
  final bool isJackpotHit;
  final bool spotlight;
  final bool dimmed;

  const CardTile({
    super.key,
    required this.finalCard,
    required this.displayCard,
    required this.nextDisplayCard,
    required this.onTap,
    required this.spinning,
    required this.pulse,
    this.isJackpotHit = false,
    this.spotlight = false,
    this.dimmed = false,
  });

  @override
  State<CardTile> createState() => _CardTileState();
}

class _CardTileState extends State<CardTile> with TickerProviderStateMixin {
  late final AnimationController _bounceController;
  late final Animation<double> _bounceAnimation;
  late final AnimationController _jackpotGlowController;
  late final AnimationController _spotlightController;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _bounceAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.07), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.07, end: 0.97), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.97, end: 1.0), weight: 40),
    ]).animate(CurvedAnimation(parent: _bounceController, curve: Curves.easeOut));

    _jackpotGlowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.isJackpotHit) {
      _jackpotGlowController.repeat(reverse: true);
    }

    _spotlightController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    if (widget.spotlight) _spotlightController.forward(from: 0.0);
  }

  @override
  void didUpdateWidget(CardTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spinning && !widget.spinning) {
      _bounceController.forward(from: 0.0);
    }
    if (widget.isJackpotHit && !oldWidget.isJackpotHit) {
      _jackpotGlowController.repeat(reverse: true);
    } else if (!widget.isJackpotHit && oldWidget.isJackpotHit) {
      _jackpotGlowController.stop();
      _jackpotGlowController.value = 0.0;
    }
    if (widget.spotlight && !oldWidget.spotlight) {
      _spotlightController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _jackpotGlowController.dispose();
    _spotlightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final cardTile = AnimatedBuilder(
      animation: _jackpotGlowController,
      builder: (_, child) {
        if (!widget.isJackpotHit) return child!;
        final v = _jackpotGlowController.value;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppColors.gold.withAlpha((150 + (80 * v)).toInt()),
                blurRadius: 8 + (14 * v),
                spreadRadius: 1 + (3 * v),
              ),
            ],
          ),
          child: child,
        );
      },
      child: ScaleTransition(
      scale: _bounceAnimation,
      child: Semantics(
        button: true,
        label: widget.spinning ? '뽑기 진행 중' : '카드: ${widget.finalCard.name}',
        child: Material(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          elevation: 2,
          clipBehavior: Clip.antiAlias,
          child: ClipRect(
            child: InkWell(
              onTap: widget.onTap,
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
                                aspectRatio: AppConstants.ygoCardAspectRatio,
                                child: ReelStrip(
                                  spinning: widget.spinning,
                                  pulse: widget.pulse,
                                  currentUrl: widget.displayCard.imageUrl,
                                  nextUrl: widget.nextDisplayCard.imageUrl,
                                ),
                              ),
                            ),
                          ),
                          if (widget.isJackpotHit)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: AnimatedBuilder(
                                  animation: _jackpotGlowController,
                                  builder: (_, _) {
                                    final v = _jackpotGlowController.value;
                                    return DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: RadialGradient(
                                          colors: [
                                            AppColors.gold.withAlpha((180 * v).toInt()),
                                            AppColors.gold.withAlpha((40 * v).toInt()),
                                            Colors.transparent,
                                          ],
                                          stops: const [0.0, 0.5, 1.0],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          // Tap overlay: ensures taps register even over HtmlElementView
                          if (!widget.spinning)
                            Positioned.fill(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: widget.onTap,
                              ),
                            ),
                          Positioned.fill(
                            child: IgnorePointer(
                              child: AnimatedOpacity(
                                opacity: widget.spinning ? 1 : 0,
                                duration: AppConstants.cardFadeOut,
                                child: AnimatedBuilder(
                                  animation: widget.pulse,
                                  builder: (_, _) {
                                    final p = (widget.pulse.value * 6) % 1;
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.finalCard.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _subInfo(widget.finalCard),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      ),
    );

    return AnimatedBuilder(
      animation: _spotlightController,
      builder: (context, child) {
        final t = _spotlightController.value;
        final pulse = sin(t * pi).clamp(0.0, 1.0);
        Widget result = child!;
        if (pulse > 0) {
          result = DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withAlpha((170 * pulse).round()),
                  blurRadius: 18 * pulse,
                  spreadRadius: 2 * pulse,
                ),
              ],
            ),
            child: result,
          );
        }
        return Transform.scale(scale: 1.0 + pulse * 0.08, child: result);
      },
      child: AnimatedOpacity(
        opacity: widget.dimmed ? 0.4 : 1.0,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
        child: cardTile,
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
