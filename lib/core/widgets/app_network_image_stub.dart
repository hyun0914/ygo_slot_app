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
    return fallback?.call(context) ?? const SizedBox.shrink();
  }
}