import 'package:flutter/material.dart';

class AppNetworkImage extends StatelessWidget {
  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final WidgetBuilder? fallback;

  const AppNetworkImage(
      this.url, {
        super.key,
        this.fit = BoxFit.cover,
        this.width,
        this.height,
        this.borderRadius,
        this.fallback,
      });

  @override
  Widget build(BuildContext context) {
    final fixedUrl = url.replaceFirst('http://', 'https://').trim();

    Widget child = Image.network(
      fixedUrl,
      fit: fit,
      width: width,
      height: height,
      errorBuilder: (_, _, _) =>
      fallback?.call(context) ?? const Icon(Icons.broken_image),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const Center(child: CircularProgressIndicator(strokeWidth: 2));
      },
    );

    if (borderRadius != null) {
      child = ClipRRect(borderRadius: borderRadius!, child: child);
    }

    return child;
  }
}