import 'package:flutter/material.dart';

class ScanLines extends StatelessWidget {
  const ScanLines({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Opacity(
      opacity: 0.14,
      child: CustomPaint(
        painter: _ScanLinePainter(
          color: theme.colorScheme.onSurface.withAlpha(35),
          step: 6.0,
        ),
      ),
    );
  }
}

class _ScanLinePainter extends CustomPainter {
  final Color color;
  final double step;

  _ScanLinePainter({required this.color, required this.step});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ScanLinePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.step != step;
  }
}