import 'package:flutter/material.dart';

import '../../../../core/app_strings.dart';
import '../../../../core/widgets/app_network_image.dart';

class Landing extends StatefulWidget {
  final Future<void> Function() onQuickStart;
  final VoidCallback onOpenCount;
  final Animation<double> spinTurns;
  final bool loading;
  final Widget? footer;
  final Widget? statBar;
  final List<String> previewImageUrls;

  const Landing({
    super.key,
    required this.onQuickStart,
    required this.onOpenCount,
    required this.spinTurns,
    required this.loading,
    this.footer,
    this.statBar,
    this.previewImageUrls = const [],
  });

  @override
  State<Landing> createState() => _LandingState();
}

class _LandingState extends State<Landing> with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;
  late final Animation<double> _heroAnim;
  late final Animation<double> _titleAnim;
  late final Animation<double> _subtitleAnim;
  late final Animation<double> _statBarAnim;
  late final Animation<double> _buttonsAnim;
  late final Animation<double> _footerAnim;

  Animation<double> _interval(double start, double end) {
    return CurvedAnimation(
      parent: _entrance,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
  }

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _heroAnim = _interval(0.0, 0.6);
    _titleAnim = _interval(0.15, 0.7);
    _subtitleAnim = _interval(0.25, 0.8);
    _statBarAnim = _interval(0.35, 0.9);
    _buttonsAnim = _interval(0.45, 1.0);
    _footerAnim = _interval(0.55, 1.0);
    _entrance.forward();
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
            children: [
              _FadeSlideIn(
                animation: _heroAnim,
                child: _HeroVisual(theme: theme, previewImageUrls: widget.previewImageUrls),
              ),
              const SizedBox(height: 14),
              _FadeSlideIn(
                animation: _titleAnim,
                child: Text(
                  AppStrings.appTitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: theme.colorScheme.primary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _FadeSlideIn(
                animation: _subtitleAnim,
                child: Text(
                  AppStrings.appSubtitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ),
              if (widget.statBar != null) ...[
                const SizedBox(height: 14),
                _FadeSlideIn(animation: _statBarAnim, child: widget.statBar!),
              ],
              const SizedBox(height: 18),
              _FadeSlideIn(
                animation: _buttonsAnim,
                child: Column(
                  children: [
                    Semantics(
                      button: true,
                      label: widget.loading ? '준비중' : '바로 시작',
                      child: _PressScale(
                        enabled: !widget.loading,
                        child: _PrimaryCta(
                          theme: theme,
                          loading: widget.loading,
                          spinTurns: widget.spinTurns,
                          onPressed: () async => widget.onQuickStart(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Semantics(
                      button: true,
                      label: '카드 수 설정',
                      child: _PressScale(
                        enabled: !widget.loading,
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: widget.loading ? null : widget.onOpenCount,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Text(AppStrings.settingsButton),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.footer != null) ...[
                const SizedBox(height: 16),
                _FadeSlideIn(animation: _footerAnim, child: widget.footer!),
              ],
            ],
          ),
        ),
      ),
    ),
    );
  }
}

/// 페이드인 + 위에서 아래로 슬라이드되는 입장 애니메이션 래퍼.
class _FadeSlideIn extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;

  const _FadeSlideIn({required this.animation, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final v = animation.value.clamp(0.0, 1.0);
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, (1 - v) * 16),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// 누르는 동안 살짝 줄어드는 마이크로 인터랙션.
/// 제스처를 가로채지 않고 포인터 상태만 관찰하므로 내부 버튼의 탭 동작에 영향을 주지 않는다.
class _PressScale extends StatefulWidget {
  final Widget child;
  final bool enabled;

  const _PressScale({required this.child, this.enabled = true});

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: widget.enabled ? (_) => _setPressed(true) : null,
      onPointerUp: widget.enabled ? (_) => _setPressed(false) : null,
      onPointerCancel: widget.enabled ? (_) => _setPressed(false) : null,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// 그라데이션 배경과 그림자로 강조한 메인 CTA 버튼.
class _PrimaryCta extends StatelessWidget {
  final ThemeData theme;
  final bool loading;
  final Animation<double> spinTurns;
  final VoidCallback onPressed;

  const _PrimaryCta({
    required this.theme,
    required this.loading,
    required this.spinTurns,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(14);
    final scheme = theme.colorScheme;

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: loading
              ? null
              : LinearGradient(
                  colors: [scheme.primary, scheme.tertiary],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
          color: loading ? scheme.surfaceContainerHighest : null,
          boxShadow: loading
              ? null
              : [
                  BoxShadow(
                    color: scheme.primary.withAlpha(90),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: radius,
            onTap: loading ? null : onPressed,
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  RotationTransition(
                    turns: spinTurns,
                    child: Icon(Icons.casino,
                        color: loading ? scheme.onSurfaceVariant : scheme.onPrimary),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    loading ? AppStrings.loadingButton : AppStrings.startButton,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: loading ? scheme.onSurfaceVariant : scheme.onPrimary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 랜딩 진입 시선을 모으는 히어로 영역.
/// 오늘의 목표 카드 아트가 있으면 부채꼴로 살짝 겹쳐 보여주고, 없으면 주사위 아이콘으로 대체한다.
class _HeroVisual extends StatelessWidget {
  final ThemeData theme;
  final List<String> previewImageUrls;

  const _HeroVisual({required this.theme, required this.previewImageUrls});

  static const _drawOrders = {
    1: [0],
    2: [0, 1],
    3: [0, 2, 1],
  };

  @override
  Widget build(BuildContext context) {
    final urls =
        previewImageUrls.where((u) => u.trim().isNotEmpty).take(3).toList();
    final order = _drawOrders[urls.length];

    return SizedBox(
      width: 168,
      height: 132,
      child: Stack(
        alignment: Alignment.center,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  theme.colorScheme.primary.withAlpha(60),
                  theme.colorScheme.primary.withAlpha(0),
                ],
              ),
            ),
          ),
          if (order == null)
            Icon(Icons.casino, size: 56, color: theme.colorScheme.primary)
          else
            for (final i in order)
              _FannedCard(theme: theme, url: urls[i], index: i, total: urls.length),
        ],
      ),
    );
  }
}

class _FannedCard extends StatelessWidget {
  final ThemeData theme;
  final String url;
  final int index;
  final int total;

  const _FannedCard({
    required this.theme,
    required this.url,
    required this.index,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final center = (total - 1) / 2;
    final delta = index - center;

    return Transform.translate(
      offset: Offset(delta * 38, delta.abs() * 10),
      child: Transform.rotate(
        angle: delta * 0.16,
        child: Container(
          width: 60,
          height: 86,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.colorScheme.surface, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(40),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: AppNetworkImage(url, fit: BoxFit.cover),
        ),
      ),
    );
  }
}