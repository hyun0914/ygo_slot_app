import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/game_providers.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/cloud_sync_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../achievements/presentation/pages/achievements_page.dart';
import '../../../auth/presentation/pages/auth_page.dart';
import '../../../random_draw/presentation/pages/history_page.dart';
import '../../../random_draw/presentation/pages/probability_page.dart';
import '../../../random_draw/presentation/widgets/notification_settings_dialog.dart';

class MorePage extends ConsumerStatefulWidget {
  const MorePage({super.key});

  @override
  ConsumerState<MorePage> createState() => _MorePageState();
}

class _MorePageState extends ConsumerState<MorePage> {
  void _openNotificationSettings() {
    if (!NotificationService.isSupported) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('이 브라우저는 알림을 지원하지 않습니다'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    showDialog(context: context, builder: (_) => const NotificationSettingsDialog());
  }

  Future<void> _login() async {
    final messenger = ScaffoldMessenger.of(context);
    final linked = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AuthPage()),
    );
    if (linked == true && mounted) {
      ref.invalidate(xpProvider);
      ref.invalidate(collectionProvider);
      ref.invalidate(favoriteIdsProvider);
      ref.invalidate(totalDrawsProvider);
      ref.invalidate(streakProvider);
      setState(() {});
      messenger.showSnackBar(const SnackBar(content: Text('계정이 연동되었습니다.')));
    }
  }

  Future<void> _sync() async {
    final messenger = ScaffoldMessenger.of(context);
    await CloudSyncService.uploadAll();
    messenger.showSnackBar(const SnackBar(content: Text('클라우드에 저장했습니다.')));
  }

  Future<void> _logout() async {
    await AuthService.signOut();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('더보기')),
      body: ListView(
        children: [
          const _SectionLabel('정보'),
          ListTile(
            leading: const Text('🏆', style: TextStyle(fontSize: 20)),
            title: const Text('도전과제'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AchievementsPage()),
            ),
          ),
          ListTile(
            leading: const Text('📋', style: TextStyle(fontSize: 20)),
            title: const Text('뽑기 기록'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HistoryPage()),
            ),
          ),
          ListTile(
            leading: const Text('📊', style: TextStyle(fontSize: 20)),
            title: const Text('확률 정보'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProbabilityPage()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('알림 설정'),
            onTap: _openNotificationSettings,
          ),
          const Divider(height: 32),
          const _SectionLabel('계정'),
          if (user == null)
            ListTile(
              leading: const Icon(Icons.cloud_sync),
              title: const Text('로그인 / 계정 연동'),
              subtitle: const Text('다른 기기와 진행 상황을 동기화할 수 있어요'),
              onTap: _login,
            )
          else ...[
            ListTile(
              leading: const Icon(Icons.account_circle),
              title: Text(AuthService.nickname ?? user.email ?? ''),
              subtitle: Text(user.email ?? ''),
            ),
            ListTile(
              leading: const Icon(Icons.cloud_upload_outlined),
              title: const Text('클라우드에 저장'),
              onTap: _sync,
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('로그아웃'),
              onTap: _logout,
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
