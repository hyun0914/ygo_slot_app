import 'package:flutter/material.dart';

import '../../../../core/widgets/app_network_image.dart';
import '../../application/collection_store.dart';
import '../../domain/collection_entry.dart';

class CollectionPage extends StatefulWidget {
  const CollectionPage({super.key});

  @override
  State<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends State<CollectionPage> {
  Map<int, CollectionEntry> _collection = {};
  bool _loading = true;
  String _search = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final data = await CollectionStore.loadAll();
    if (!mounted) return;
    setState(() {
      _collection = data;
      _loading = false;
    });
  }

  List<CollectionEntry> get _filtered {
    final all = _collection.values.toList()
      ..sort((a, b) => b.count.compareTo(a.count));
    if (_search.isEmpty) return all;
    final q = _search.toLowerCase();
    return all.where((e) => e.name.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = _collection.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('카드 도감'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '$total종',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : total == 0
              ? _EmptyState()
              : Column(
                  children: [
                    _CollectionSummary(collection: _collection),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          hintText: '카드 이름 검색',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                        onChanged: (v) => setState(() => _search = v),
                      ),
                    ),
                    Expanded(
                      child: _CollectionGrid(entries: _filtered),
                    ),
                  ],
                ),
    );
  }
}

class _CollectionSummary extends StatelessWidget {
  final Map<int, CollectionEntry> collection;

  const _CollectionSummary({required this.collection});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = collection.length;
    final totalDrawn = collection.values.fold(0, (s, e) => s + e.count);
    final mostDrawn = collection.values.isEmpty
        ? null
        : collection.values.reduce((a, b) => a.count > b.count ? a : b);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withAlpha(80),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _StatBox(label: '수집 종류', value: '$total종', emoji: '📚'),
          const SizedBox(width: 8),
          _StatBox(label: '총 뽑힘', value: '$totalDrawn회', emoji: '🎴'),
          if (mostDrawn != null) ...[
            const SizedBox(width: 8),
            Expanded(
              child: _StatBox(
                label: '최다 등장',
                value: mostDrawn.name,
                sub: '${mostDrawn.count}회',
                emoji: '👑',
                flex: true,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final String emoji;
  final bool flex;

  const _StatBox({
    required this.label,
    required this.value,
    this.sub,
    required this.emoji,
    this.flex = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final w = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$emoji $label',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 10,
              )),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          if (sub != null)
            Text(sub!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                )),
        ],
      ),
    );

    if (flex) return w;
    return IntrinsicWidth(child: w);
  }
}

class _CollectionGrid extends StatelessWidget {
  final List<CollectionEntry> entries;

  const _CollectionGrid({required this.entries});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Center(child: Text('검색 결과가 없습니다'));
    }

    return LayoutBuilder(builder: (context, constraints) {
      final cols = (constraints.maxWidth / 110).floor().clamp(3, 8);
      return GridView.builder(
        padding: const EdgeInsets.all(10),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          childAspectRatio: 59 / 100,
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
        ),
        itemCount: entries.length,
        itemBuilder: (context, i) => _CollectionCard(entry: entries[i]),
      );
    });
  }
}

class _CollectionCard extends StatelessWidget {
  final CollectionEntry entry;

  const _CollectionCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(
              fit: StackFit.expand,
              children: [
                AppNetworkImage(
                  entry.imageUrl,
                  fit: BoxFit.cover,
                ),
                if (entry.count > 1)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer.withAlpha(230),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'x${entry.count}',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          entry.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: theme.textTheme.labelSmall?.copyWith(fontSize: 9),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('📚', style: const TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text(
            '아직 수집한 카드가 없습니다',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '카드를 뽑으면 자동으로 도감에 추가됩니다!',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
