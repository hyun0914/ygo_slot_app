import 'package:flutter/material.dart';
import '../../../../../core/app_constants.dart';
import '../../../../../core/widgets/app_network_image.dart';
import '../../../../../core/widgets/ygo_card_back.dart';
import '../../domain/daily_slot_rule.dart';

class TargetPreviewDialog extends StatelessWidget {
  final SlotTarget target;

  const TargetPreviewDialog({super.key, required this.target});

  static void show(BuildContext context, SlotTarget target) {
    final url = (target.imageUrl ?? '').trim();
    if (url.isEmpty) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => TargetPreviewDialog(target: target),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final url = (target.imageUrl ?? '').trim();

    const sidePad = 16.0;
    const extraSpace = 14.0;
    final cardWidth = (size.width * 0.52).clamp(180.0, 260.0);
    final dialogWidth = (cardWidth + (sidePad * 2) + (extraSpace * 2)).clamp(0.0, size.width - 32);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: SizedBox(
        width: dialogWidth,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Container(
            color: theme.colorScheme.surface,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        target.cardName ?? '카드 미리보기',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      tooltip: '닫기',
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: extraSpace),
                  child: SizedBox(
                    width: cardWidth,
                    child: AspectRatio(
                      aspectRatio: AppConstants.ygoCardAspectRatio,
                      child: Hero(
                        tag: 'slot_card_${target.cardId}',
                        child: AppNetworkImage(
                          url,
                          fit: BoxFit.contain,
                          fallback: (_) => const YgoCardBack(label: 'YGO'),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.check),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Text('확인'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
