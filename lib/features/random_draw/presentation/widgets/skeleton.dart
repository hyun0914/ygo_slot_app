import 'package:flutter/material.dart';

class SkeletonGrid extends StatelessWidget {
  final int crossAxisCount;
  const SkeletonGrid({super.key, required this.crossAxisCount});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: crossAxisCount,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.7,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (_, _) => const _SkeletonTile(),
    );
  }
}

class _SkeletonTile extends StatefulWidget {
  const _SkeletonTile();

  @override
  State<_SkeletonTile> createState() => _SkeletonTileState();
}

class _SkeletonTileState extends State<_SkeletonTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.colorScheme.surfaceContainerHighest;
    final highlight = theme.colorScheme.surface;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value * 3 - 1;
        return ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: CustomPaint(
            painter: _ShimmerPainter(t: t, base: base, highlight: highlight),
            child: Container(color: base),
          ),
        );
      },
    );
  }
}

class _ShimmerPainter extends CustomPainter {
  final double t;
  final Color base;
  final Color highlight;

  _ShimmerPainter({required this.t, required this.base, required this.highlight});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = base);

    final shimmerWidth = size.width * 0.6;
    final dx = t * size.width;
    final shimmerRect = Rect.fromLTWH(dx - shimmerWidth, 0, shimmerWidth, size.height);

    final shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        base.withAlpha(0),
        highlight.withAlpha(90),
        base.withAlpha(0),
      ],
      stops: const [0.2, 0.5, 0.8],
    ).createShader(shimmerRect);

    canvas.saveLayer(rect, Paint());
    canvas.drawRect(rect, Paint()..shader = shader);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ShimmerPainter old) {
    return old.t != t || old.base != base || old.highlight != highlight;
  }
}