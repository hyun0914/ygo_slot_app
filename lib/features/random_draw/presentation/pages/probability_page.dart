import 'package:flutter/material.dart';

class ProbabilityPage extends StatelessWidget {
  const ProbabilityPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('확률 정보'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // ① 데일리 풀
          const _SectionTitle('데일리 풀'),
          _InfoCard(
            child: Text(
              '매일 YGOPRODeck에서 무작위로 200장을 가져와 당일 풀로 사용합니다.\n'
              '뽑기는 이 풀에서 모드에 따라 3 / 5 / 7장을 무작위로 선택합니다.',
              style: theme.textTheme.bodyMedium,
            ),
          ),

          // ② 날 종류별 출현 확률
          const _SectionTitle('날 종류별 출현 확률'),
          _InfoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '날 종류는 타겟 구성과 무관하며, 연출(라벨·아이콘·색상, 보스 잭팟 발동 여부)에만 영향을 줍니다.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                _ProbTable(
                  headers: const ['모드', '일반', '보스'],
                  rows: const [
                    ['도전 (3장)', '80%', '20%'],
                    ['기본 (5장)', '90%', '10%'],
                    ['편안 (7장)', '88%', '12%'],
                  ],
                  highlightCols: const {2: _ColHighlight.amber},
                ),
              ],
            ),
          ),

          // ③ 잭팟 확률
          const _SectionTitle('잭팟 확률 (특정 카드 3장 전부 적중)'),
          _InfoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '날 종류와 무관하게 매일 특정 카드 3장이 오늘의 타겟으로 고정됩니다. '
                  '뽑은 카드에 3장 전부 들어있으면 잭팟입니다.\n'
                  '공식: k×(k-1)×(k-2) / (200×199×198)',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                _ProbTable(
                  headers: const ['모드', '확률', '약 n분의 1'],
                  rows: const [
                    ['도전 (3장)', '≈ 0.000076%', '약 1,313,400'],
                    ['기본 (5장)', '≈ 0.00076%', '약 131,340'],
                    ['편안 (7장)', '≈ 0.0027%', '약 37,543'],
                  ],
                  highlightCols: const {1: _ColHighlight.amber, 2: _ColHighlight.amber},
                ),
                const SizedBox(height: 10),
                Text(
                  '잭팟 확률이 매우 낮은 대신, 천장(피티) 시스템이 잭팟 없이 흘러간 뽑기 횟수를 누적해 '
                  '소프트 천장(200회)부터 부족한 타겟을 보너스로 채워줄 확률이 점차 오르고, '
                  '하드 천장(500회)에서는 확정 잭팟으로 이어집니다.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 열 강조 종류
// ---------------------------------------------------------------------------
enum _ColHighlight { amber, secondary }

// ---------------------------------------------------------------------------
// 섹션 제목
// ---------------------------------------------------------------------------
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 6),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 정보 카드
// ---------------------------------------------------------------------------
class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// 확률 표
// ---------------------------------------------------------------------------
class _ProbTable extends StatelessWidget {
  const _ProbTable({
    required this.headers,
    required this.rows,
    this.highlightCols = const {},
  });

  final List<String> headers;
  final List<List<String>> rows;
  // key: 0-based 열 인덱스, value: 강조 색상 종류
  final Map<int, _ColHighlight> highlightCols;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colCount = headers.length;

    TextStyle? colStyle(int colIndex, {bool isHeader = false}) {
      final hl = highlightCols[colIndex];
      Color? color;
      if (hl == _ColHighlight.amber) {
        color = Colors.amber[700];
      } else if (hl == _ColHighlight.secondary) {
        color = theme.colorScheme.secondary;
      }
      final base = isHeader
          ? theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold)
          : theme.textTheme.bodySmall;
      return color != null ? base?.copyWith(color: color) : base;
    }

    TableColumnWidth colWidth(int i) {
      if (i == 0) return const IntrinsicColumnWidth();
      return const FlexColumnWidth();
    }

    Widget cell(String text, int colIndex, {bool isHeader = false}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
        child: Text(
          text,
          textAlign: colIndex == 0 ? TextAlign.left : TextAlign.center,
          style: colStyle(colIndex, isHeader: isHeader),
        ),
      );
    }

    return Table(
      columnWidths: {
        for (int i = 0; i < colCount; i++) i: colWidth(i),
      },
      border: TableBorder(
        horizontalInside: BorderSide(
          color: theme.colorScheme.outlineVariant,
          width: 0.5,
        ),
      ),
      children: [
        // 헤더 행
        TableRow(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.outlineVariant,
                width: 1,
              ),
            ),
          ),
          children: [
            for (int i = 0; i < colCount; i++)
              cell(headers[i], i, isHeader: true),
          ],
        ),
        // 데이터 행
        for (final row in rows)
          TableRow(
            children: [
              for (int i = 0; i < colCount; i++)
                cell(row[i], i),
            ],
          ),
      ],
    );
  }
}
