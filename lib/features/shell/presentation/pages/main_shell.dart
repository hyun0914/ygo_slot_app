import 'package:flutter/material.dart';

import '../../../collection/presentation/pages/collection_page.dart';
import '../../../decoder/presentation/pages/decoder_page.dart';
import '../../../favorites/presentation/pages/favorites_page.dart';
import '../../../random_draw/presentation/pages/random_draw_page.dart';
import '../../../stats/presentation/pages/stats_page.dart';
import 'more_page.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with SingleTickerProviderStateMixin {
  int _index = 0;
  late final AnimationController _fade;

  static const _pages = [
    RandomDrawPage(),
    DecoderPage(),
    CollectionPage(),
    FavoritesPage(),
    StatsPage(),
    MorePage(),
  ];

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      value: 1,
    );
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  void _selectTab(int i) {
    if (i == _index) return;
    setState(() => _index = i);
    _fade
      ..value = 0
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const radius = BorderRadius.vertical(top: Radius.circular(20));

    return Scaffold(
      body: FadeTransition(
        opacity: CurvedAnimation(parent: _fade, curve: Curves.easeOut),
        // 탭은 IndexedStack으로 유지해 각 페이지의 상태(스크롤 위치 등)를 보존하고,
        // 전환 시에는 페이드만 살짝 입혀 부드러운 느낌을 준다.
        child: IndexedStack(index: _index, children: _pages),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(25),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: _selectTab,
            backgroundColor: theme.colorScheme.surfaceContainer,
            indicatorColor: theme.colorScheme.primaryContainer,
            indicatorShape: const StadiumBorder(),
            elevation: 0,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.casino_outlined),
                selectedIcon: Icon(Icons.casino),
                label: '뽑기',
              ),
              NavigationDestination(
                icon: Icon(Icons.psychology_outlined),
                selectedIcon: Icon(Icons.psychology),
                label: '디코더',
              ),
              NavigationDestination(
                icon: Icon(Icons.style_outlined),
                selectedIcon: Icon(Icons.style),
                label: '컬렉션',
              ),
              NavigationDestination(
                icon: Icon(Icons.bookmark_border),
                selectedIcon: Icon(Icons.bookmark),
                label: '즐겨찾기',
              ),
              NavigationDestination(
                icon: Icon(Icons.bar_chart_outlined),
                selectedIcon: Icon(Icons.bar_chart),
                label: '통계',
              ),
              NavigationDestination(
                icon: Icon(Icons.more_horiz),
                selectedIcon: Icon(Icons.more_horiz),
                label: '더보기',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
