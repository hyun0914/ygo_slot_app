import 'package:flutter/material.dart';

class YgoCardBack extends StatelessWidget {
  final BorderRadius? borderRadius;
  final String? label;

  const YgoCardBack({
    super.key,
    this.borderRadius,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.primary.withAlpha(200),
              theme.colorScheme.secondary.withAlpha(160),
              theme.colorScheme.tertiary.withAlpha(140),
            ],
          ),
        ),
        child: Stack(
          children: [
            // 은은한 패턴 느낌
            Positioned.fill(
              child: Opacity(
                opacity: 0.12,
                child: CustomPaint(
                  painter: _SwirlPainter(color: theme.colorScheme.onPrimary),
                ),
              ),
            ),
            // 중앙 로고/텍스트 느낌
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.style,
                          size: 30,
                          color: theme.colorScheme.onPrimary,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          label ?? 'YGO',
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.visible,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.onPrimary,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2,
                            height: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _SwirlPainter extends CustomPainter {
  final Color color;
  _SwirlPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final center = Offset(size.width / 2, size.height / 2);
    final maxR = (size.shortestSide / 2) * 1.2;

    for (double r = maxR; r > 10; r -= 14) {
      final rect = Rect.fromCircle(center: center, radius: r);
      canvas.drawArc(rect, 0.2 * r / 20, 5.0, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SwirlPainter oldDelegate) => false;
}