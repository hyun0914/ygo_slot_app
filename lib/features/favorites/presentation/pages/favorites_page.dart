import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/game_providers.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/ygo_card_back.dart';
import '../../application/favorites_store.dart';

class FavoritesPage extends ConsumerWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final idsAsync = ref.watch(favoriteIdsProvider);
    final collectionAsync = ref.watch(collectionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('즐겨찾기'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${idsAsync.valueOrNull?.length ?? 0}장',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: (idsAsync.isLoading || collectionAsync.isLoading)
          ? const Center(child: CircularProgressIndicator())
          : Builder(builder: (context) {
              final ids = idsAsync.valueOrNull ?? {};
              final collection = collectionAsync.valueOrNull ?? {};

              final favorites = ids
                  .where((id) => collection.containsKey(id))
                  .map((id) => FavoriteCardEntry.fromCollection(collection[id]!))
                  .toList()
                ..sort((a, b) => a.name.compareTo(b.name));

              if (favorites.isEmpty) return _EmptyState();

              return LayoutBuilder(builder: (context, constraints) {
                final cols = (constraints.maxWidth / 110).floor().clamp(2, 8);
                return GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    childAspectRatio: 59 / 102,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: favorites.length,
                  itemBuilder: (_, i) => _FavCard(
                    entry: favorites[i],
                    onRemove: () => ref
                        .read(favoriteIdsProvider.notifier)
                        .toggle(favorites[i].id),
                  ),
                );
              });
            }),
    );
  }
}

class _FavCard extends StatelessWidget {
  final FavoriteCardEntry entry;
  final VoidCallback onRemove;

  const _FavCard({required this.entry, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: AppNetworkImage(
                  entry.imageUrl,
                  fit: BoxFit.cover,
                  fallback: (_) => const YgoCardBack(label: 'YGO'),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer.withAlpha(220),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.bookmark_remove,
                      size: 12,
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              ),
            ],
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
          const Text('🔖', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text('즐겨찾기한 카드가 없습니다', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            '카드 타일을 탭하면 상세 정보에서 북마크할 수 있습니다.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
