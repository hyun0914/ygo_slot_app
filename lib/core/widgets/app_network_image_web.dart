import 'dart:ui_web' as ui;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

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

  static final Set<String> _registered = <String>{};

  @override
  Widget build(BuildContext context) {
    final fixedUrl = url.replaceFirst('http://', 'https://').trim();

    if (fixedUrl.isEmpty) {
      return fallback?.call(context) ?? const SizedBox.shrink();
    }

    final viewType =
        'img_${fixedUrl.hashCode}_${fit.index}_${width ?? 0}_${height ?? 0}';

    if (_registered.add(viewType)) {
      ui.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
        final img = web.HTMLImageElement()
          ..src = fixedUrl
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.objectFit = _objectFitCss(fit)
          ..loading = 'lazy'
          ..decoding = 'async';

        return img;
      });
    }

    Widget imageView = HtmlElementView(viewType: viewType);

    if (width != null || height != null) {
      imageView = SizedBox(width: width, height: height, child: imageView);
    }

    Widget child = Stack(
      fit: StackFit.passthrough,
      children: [
        if (fallback != null) Positioned.fill(child: fallback!(context)),
        Positioned.fill(child: imageView),
      ],
    );

    if (borderRadius != null) {
      child = ClipRRect(borderRadius: borderRadius!, child: child);
    }

    return child;
  }

  String _objectFitCss(BoxFit fit) {
    switch (fit) {
      case BoxFit.contain:
        return 'contain';
      case BoxFit.cover:
        return 'cover';
      case BoxFit.fill:
        return 'fill';
      case BoxFit.fitHeight:
        return 'contain';
      case BoxFit.fitWidth:
        return 'contain';
      case BoxFit.none:
        return 'none';
      case BoxFit.scaleDown:
        return 'scale-down';
    }
  }
}