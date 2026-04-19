import 'package:flutter/material.dart';
import '../../../../../core/app_strings.dart';

class CountPickerSheet extends StatefulWidget {
  final int initialCount;
  final void Function(int count) onApply;

  const CountPickerSheet({
    super.key,
    required this.initialCount,
    required this.onApply,
  });

  @override
  State<CountPickerSheet> createState() => _CountPickerSheetState();
}

class _CountPickerSheetState extends State<CountPickerSheet> {
  late int _tCount;

  @override
  void initState() {
    super.initState();
    _tCount = (widget.initialCount == 3 || widget.initialCount == 5 || widget.initialCount == 7)
        ? widget.initialCount
        : 5;
  }

  void _applyAndClose() {
    Navigator.of(context).pop();
    widget.onApply(_tCount);
  }

  Widget _modeCard({
    required BuildContext context,
    required String title,
    required String desc,
    required int value,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    final selected = _tCount == value;

    return Material(
      color: selected ? theme.colorScheme.primary.withAlpha(16) : theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => setState(() => _tCount = value),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? theme.colorScheme.primary.withAlpha(140)
                  : theme.dividerColor,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: selected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      desc,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? theme.colorScheme.primary : Colors.transparent,
                  border: Border.all(
                    color: selected ? theme.colorScheme.primary : theme.dividerColor,
                    width: 2,
                  ),
                ),
                child: selected
                    ? Icon(Icons.check, size: 14, color: theme.colorScheme.onPrimary)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16, 10, 16,
          16 + MediaQuery.of(context).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.modePickerTitle,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              AppStrings.modePickerSubtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            _modeCard(
              context: context,
              title: AppStrings.modeChallengeTitle,
              desc: AppStrings.modeChallengeDesc,
              value: 3,
              icon: Icons.whatshot,
            ),
            const SizedBox(height: 10),
            _modeCard(
              context: context,
              title: AppStrings.modeDefaultTitle,
              desc: AppStrings.modeDefaultDesc,
              value: 5,
              icon: Icons.casino,
            ),
            const SizedBox(height: 10),
            _modeCard(
              context: context,
              title: AppStrings.modeComfortTitle,
              desc: AppStrings.modeComfortDesc,
              value: 7,
              icon: Icons.emoji_events,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _tCount = 5),
                    child: const Text(AppStrings.modeResetButton),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _applyAndClose,
                    child: const Text('적용'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
