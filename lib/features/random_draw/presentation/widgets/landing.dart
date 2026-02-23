import 'package:flutter/material.dart';

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
                '유희왕 슬롯',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '데일리 슬롯 룰은 하루 동안 고정돼요.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
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
                        Text(loading ? '🎲 준비중...' : '🔥 바로 시작'),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: loading ? null : onOpenCount,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('⚙️ 카드 수 설정'),
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