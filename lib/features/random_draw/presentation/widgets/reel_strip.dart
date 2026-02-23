import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/ygo_card_back.dart';

import 'scan_lines.dart';

class ReelStrip extends StatelessWidget {
  final String? currentUrl;
  final String? nextUrl;
  final bool spinning;
  final Animation<double> pulse;

  const ReelStrip({
    super.key,
    required this.currentUrl,
    required this.nextUrl,
    required this.spinning,
    required this.pulse,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget buildImage(String? u) {
      final s = (u ?? '').trim();
      if (s.isEmpty) return const YgoCardBack(label: 'YGO');
      return AppNetworkImage(
        s,
        fit: BoxFit.contain,
        fallback: (_) => const YgoCardBack(label: 'YGO'),
      );
    }

    if (!spinning) return buildImage(currentUrl);

    return AnimatedBuilder(
      animation: pulse,
      builder: (_, _) {
        final t = (pulse.value * 16) % 1;
        final glow = (70 + (sin(t * pi * 2).abs() * 120)).toInt();

        return ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              FractionalTranslation(
                translation: Offset(0, -t),
                child: buildImage(currentUrl),
              ),
              FractionalTranslation(
                translation: Offset(0, 1 - t),
                child: buildImage(nextUrl),
              ),
              const IgnorePointer(child: ScanLines()),
              Align(
                alignment: Alignment.center,
                child: Container(
                  height: 10,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.transparent,
                        theme.colorScheme.primary.withAlpha(glow),
                        Colors.transparent,
                      ],
                    ),
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
                          theme.colorScheme.surface.withAlpha(160),
                          Colors.transparent,
                          Colors.transparent,
                          theme.colorScheme.surface.withAlpha(160),
                        ],
                        stops: const [0.0, 0.20, 0.80, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}