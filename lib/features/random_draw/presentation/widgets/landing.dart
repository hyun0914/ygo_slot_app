import 'package:flutter/material.dart';

import '../../../../core/app_strings.dart';

class Landing extends StatelessWidget {
  final Future<void> Function() onQuickStart;
  final VoidCallback onOpenCount;
  final Animation<double> spinTurns;
  final bool loading;
  final Widget? footer;

  const Landing({
    super.key,
    required this.onQuickStart,
    required this.onOpenCount,
    required this.spinTurns,
    required this.loading,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.casino, size: 56, color: theme.colorScheme.primary),
              const SizedBox(height: 14),
              Text(
                AppStrings.appTitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                AppStrings.appSubtitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              Semantics(
                button: true,
                label: loading ? '준비중' : '바로 시작',
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: loading ? null : () async => onQuickStart(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          RotationTransition(turns: spinTurns, child: const Icon(Icons.casino)),
                          const SizedBox(width: 10),
                          Text(loading ? AppStrings.loadingButton : AppStrings.startButton),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Semantics(
                button: true,
                label: '카드 수 설정',
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: loading ? null : onOpenCount,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(AppStrings.settingsButton),
                    ),
                  ),
                ),
              ),
              ?footer,
            ],
          ),
        ),
      ),
    );
  }
}