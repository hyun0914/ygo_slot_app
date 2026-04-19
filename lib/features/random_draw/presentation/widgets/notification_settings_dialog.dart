import 'package:flutter/material.dart';
import '../../../../../core/services/notification_service.dart';

class NotificationSettingsDialog extends StatefulWidget {
  const NotificationSettingsDialog({super.key});

  @override
  State<NotificationSettingsDialog> createState() => _NotificationSettingsDialogState();
}

class _NotificationSettingsDialogState extends State<NotificationSettingsDialog> {
  String _permission = 'default';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadPermission();
  }

  Future<void> _loadPermission() async {
    final p = await NotificationService.getPermission();
    if (mounted) setState(() => _permission = p);
  }

  Future<void> _request() async {
    setState(() => _loading = true);
    final granted = await NotificationService.requestPermission();
    if (mounted) {
      setState(() {
        _permission = granted ? 'granted' : 'denied';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final (permLabel, permColor, permEmoji) = switch (_permission) {
      'granted' => ('허용됨', Colors.green, '✅'),
      'denied'  => ('거부됨', theme.colorScheme.error, '❌'),
      _         => ('미설정', theme.colorScheme.onSurfaceVariant, '❓'),
    };

    return AlertDialog(
      title: const Text('🔔 알림 설정'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '오늘 뽑기를 잊지 않도록 브라우저 알림을 받을 수 있습니다.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text('현재 상태: $permEmoji ', style: theme.textTheme.bodyMedium),
              Text(permLabel,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: permColor,
                    fontWeight: FontWeight.bold,
                  )),
            ],
          ),
          if (_permission != 'granted') ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _request,
                child: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('알림 허용하기'),
              ),
            ),
          ],
          if (_permission == 'granted') ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => NotificationService.show(
                  '🎴 테스트 알림',
                  body: '알림이 정상적으로 작동합니다!',
                ),
                icon: const Icon(Icons.notifications_active, size: 18),
                label: const Text('테스트 알림 보내기'),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('닫기'),
        ),
      ],
    );
  }
}
