import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/app_network_image.dart';
import '../../application/decoder_store.dart';
import '../../domain/decoder_card.dart';
import '../../domain/guess_result.dart';

class DecoderPage extends ConsumerWidget {
  const DecoderPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(decoderProvider);

    if (state.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (state.error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('디코더')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 12),
                Text(state.error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () =>
                      ref.read(decoderProvider.notifier).retry(),
                  child: const Text('다시 시도'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('디코더'),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.key_rounded,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 4),
                Text('${state.hintTokens}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StatusBar(state: state),
              const SizedBox(height: 12),
              _HintPanel(state: state),
              if (state.allCardGuesses.isNotEmpty) ...[
                const SizedBox(height: 12),
                _GuessTable(guesses: state.allCardGuesses),
              ],
              const SizedBox(height: 12),
              if (state.isWon)
                _WinSection(state: state)
              else if (!state.canGuessToday)
                _NoGuessesCard()
              else
                _CardBrowserSection(state: state),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Status bar
// ─────────────────────────────────────────────────────────────────

class _StatusBar extends StatelessWidget {
  final DecoderState state;
  const _StatusBar({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget dots(int total, int remaining, Color activeColor) => Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(total, (i) {
            final active = i < remaining;
            return Padding(
              padding: const EdgeInsets.only(right: 3),
              child: Icon(
                active ? Icons.circle : Icons.circle_outlined,
                size: 12,
                color: active
                    ? activeColor
                    : theme.colorScheme.onSurfaceVariant.withAlpha(80),
              ),
            );
          }),
        );

    return Row(
      children: [
        const Icon(Icons.track_changes_rounded, size: 14),
        const SizedBox(width: 4),
        Text('추측 ', style: theme.textTheme.bodySmall),
        if (state.isWon)
          Text('정답!',
              style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.green, fontWeight: FontWeight.bold))
        else
          dots(3, state.guessesLeftToday, theme.colorScheme.primary),
        const SizedBox(width: 16),
        const Icon(Icons.key_rounded, size: 14),
        const SizedBox(width: 4),
        Text('힌트 ', style: theme.textTheme.bodySmall),
        dots(5, state.hintTokens, theme.colorScheme.tertiary),
        const Spacer(),
        Text(
          '${state.cardIndex + 1}번째',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Hint panel
// ─────────────────────────────────────────────────────────────────

class _HintPanel extends ConsumerWidget {
  final DecoderState state;
  const _HintPanel({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final answer = state.answerCard;
    if (answer == null) return const SizedBox.shrink();

    final revealed = state.allRevealedKeys.toSet();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.visibility_outlined, size: 16),
                const SizedBox(width: 6),
                Text(
                  '공개된 정보 (${revealed.length}/${kHintKeys.length})',
                  style: theme.textTheme.titleSmall,
                ),
                const Spacer(),
                if (!state.isWon)
                  FilledButton.tonalIcon(
                    onPressed: state.canUseHint
                        ? () =>
                            ref.read(decoderProvider.notifier).useHint()
                        : null,
                    icon: const Icon(Icons.key_rounded, size: 14),
                    label: Text('힌트 사용 (${state.hintTokens})'),
                    style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kHintKeys.map((key) {
                final isRevealed = revealed.contains(key);
                final isFree = key == state.freeRevealKey;
                return _HintChip(
                  label: kHintLabels[key] ?? key,
                  value: isRevealed ? answer.hintValue(key) : null,
                  isFree: isFree && isRevealed,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _HintChip extends StatelessWidget {
  final String label;
  final String? value;
  final bool isFree;

  const _HintChip({required this.label, this.value, this.isFree = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRevealed = value != null;

    Color bg;
    Color border;
    Color labelColor;

    if (isRevealed) {
      if (isFree) {
        bg = theme.colorScheme.tertiaryContainer.withAlpha(180);
        border = theme.colorScheme.tertiary.withAlpha(120);
        labelColor = theme.colorScheme.onTertiaryContainer;
      } else {
        bg = theme.colorScheme.primaryContainer.withAlpha(180);
        border = theme.colorScheme.primary.withAlpha(120);
        labelColor = theme.colorScheme.onPrimaryContainer;
      }
    } else {
      bg = theme.colorScheme.surfaceContainerHighest;
      border = theme.colorScheme.outline.withAlpha(60);
      labelColor = theme.colorScheme.onSurfaceVariant;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: labelColor.withAlpha(180))),
          const SizedBox(height: 2),
          Text(
            isRevealed ? value! : '???',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: labelColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// No guesses today
// ─────────────────────────────────────────────────────────────────

class _NoGuessesCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.errorContainer.withAlpha(80),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.lock_clock, color: theme.colorScheme.error),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('오늘 추측 횟수를 모두 사용했어요',
                      style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.error,
                          fontWeight: FontWeight.bold)),
                  Text('자정에 3번의 추측이 다시 생겨요.',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onErrorContainer)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Win section
// ─────────────────────────────────────────────────────────────────

class _WinSection extends ConsumerWidget {
  final DecoderState state;
  const _WinSection({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final answer = state.answerCard;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.green.withAlpha(120), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.emoji_events_rounded,
                    color: Colors.amber, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('정답입니다!',
                          style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.bold)),
                      if (answer != null)
                        Text(answer.name,
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
            if (answer != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 130,
                child: AppNetworkImage(
                  answer.imageUrl,
                  fit: BoxFit.contain,
                  fallback: (_) =>
                      const Icon(Icons.image_not_supported, size: 40),
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () =>
                    ref.read(decoderProvider.notifier).advanceCard(),
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('다음 카드 도전하기'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Card browser — filters + list + selection
// ─────────────────────────────────────────────────────────────────

class _CardBrowserSection extends ConsumerStatefulWidget {
  final DecoderState state;
  const _CardBrowserSection({required this.state});

  @override
  ConsumerState<_CardBrowserSection> createState() =>
      _CardBrowserSectionState();
}

class _CardBrowserSectionState extends ConsumerState<_CardBrowserSection> {
  late final TextEditingController _searchCtrl;
  late final TextEditingController _atkMinCtrl;
  late final TextEditingController _atkMaxCtrl;
  late final TextEditingController _defMinCtrl;
  late final TextEditingController _defMaxCtrl;
  int _displayCount = 50;

  @override
  void initState() {
    super.initState();
    final f = widget.state.activeFilters;
    _searchCtrl = TextEditingController(text: widget.state.filterSearch);
    _atkMinCtrl = TextEditingController(text: f['atkMin'] ?? '');
    _atkMaxCtrl = TextEditingController(text: f['atkMax'] ?? '');
    _defMinCtrl = TextEditingController(text: f['defMin'] ?? '');
    _defMaxCtrl = TextEditingController(text: f['defMax'] ?? '');
  }

  @override
  void didUpdateWidget(_CardBrowserSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldF = oldWidget.state.activeFilters;
    final newF = widget.state.activeFilters;

    // 필터/검색 변경 시 목록 초기화
    final filtersChanged =
        oldWidget.state.filterSearch != widget.state.filterSearch ||
        oldF.toString() != newF.toString();
    if (filtersChanged) {
      _displayCount = 50;
    }

    if (oldWidget.state.filterSearch != widget.state.filterSearch &&
        _searchCtrl.text != widget.state.filterSearch) {
      _searchCtrl.text = widget.state.filterSearch;
    }
    _syncCtrl(_atkMinCtrl, oldF['atkMin'], newF['atkMin']);
    _syncCtrl(_atkMaxCtrl, oldF['atkMax'], newF['atkMax']);
    _syncCtrl(_defMinCtrl, oldF['defMin'], newF['defMin']);
    _syncCtrl(_defMaxCtrl, oldF['defMax'], newF['defMax']);
  }

  void _syncCtrl(TextEditingController ctrl, String? oldVal, String? newVal) {
    if (oldVal != newVal && ctrl.text != (newVal ?? '')) {
      ctrl.text = newVal ?? '';
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _atkMinCtrl.dispose();
    _atkMaxCtrl.dispose();
    _defMinCtrl.dispose();
    _defMaxCtrl.dispose();
    super.dispose();
  }

  List<(String, String)> _typeOptions(List<DecoderCard> pool) {
    final seen = <String>{};
    final list = <(String, String)>[];
    for (final c in pool) {
      if (seen.add(c.frameType)) list.add((c.frameType, c.monsterTypeKr));
    }
    list.sort((a, b) => a.$2.compareTo(b.$2));
    return list;
  }

  List<(String, String)> _attrOptions(List<DecoderCard> pool) {
    final seen = <String>{};
    final list = <(String, String)>[];
    for (final c in pool) {
      if (c.attribute.isEmpty) continue;
      if (seen.add(c.attribute)) list.add((c.attribute, c.attributeKr));
    }
    list.sort((a, b) => a.$2.compareTo(b.$2));
    return list;
  }

  List<(String, String)> _levelOptions(List<DecoderCard> pool) {
    final seen = <String>{};
    final list = <(String, String)>[];
    for (final c in pool) {
      final type = c.isLink ? 'link' : c.isXyz ? 'rank' : 'level';
      final key = '${type}_${c.levelRankLink}';
      if (seen.add(key)) list.add((key, c.levelRankLinkDisplay));
    }
    list.sort((a, b) {
      const order = {'level': 0, 'rank': 1, 'link': 2};
      final aParts = a.$1.split('_');
      final bParts = b.$1.split('_');
      final typeComp =
          (order[aParts[0]] ?? 3).compareTo(order[bParts[0]] ?? 3);
      if (typeComp != 0) return typeComp;
      return int.parse(aParts[1]).compareTo(int.parse(bParts[1]));
    });
    return list;
  }

  List<(String, String)> _raceOptions(List<DecoderCard> pool) {
    final seen = <String>{};
    final list = <(String, String)>[];
    for (final c in pool) {
      if (c.race.isEmpty) continue;
      if (seen.add(c.race)) list.add((c.race, c.raceKr));
    }
    list.sort((a, b) => a.$2.compareTo(b.$2));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = widget.state;
    final notifier = ref.read(decoderProvider.notifier);

    final filtered = state.filteredPool;
    final display = filtered.take(_displayCount).toList();
    final hasMore = filtered.length > _displayCount;
    final browserHeight = MediaQuery.of(context).size.height * 0.6;

    return Card(
      child: SizedBox(
        height: browserHeight,
        child: Column(
          children: [
            // ── 필터 바 ──
            SizedBox(
              height: 52,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    _FilterDropdown(
                      label: '종류',
                      options: _typeOptions(state.pool),
                      selectedRaw: state.activeFilters['monsterType'],
                      onSelected: (v) =>
                          notifier.setFilter('monsterType', v),
                    ),
                    const SizedBox(width: 8),
                    _FilterDropdown(
                      label: '속성',
                      options: _attrOptions(state.pool),
                      selectedRaw: state.activeFilters['attribute'],
                      onSelected: (v) =>
                          notifier.setFilter('attribute', v),
                    ),
                    const SizedBox(width: 8),
                    _FilterDropdown(
                      label: '레벨',
                      options: _levelOptions(state.pool),
                      selectedRaw: state.activeFilters['levelRankLink'],
                      onSelected: (v) =>
                          notifier.setFilter('levelRankLink', v),
                    ),
                    const SizedBox(width: 8),
                    _FilterDropdown(
                      label: '종족',
                      options: _raceOptions(state.pool),
                      selectedRaw: state.activeFilters['race'],
                      onSelected: (v) => notifier.setFilter('race', v),
                    ),
                  ],
                ),
              ),
            ),

            // ── 검색 필드 ──
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: '카드 이름 검색...',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  suffixIcon: state.filterSearch.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            _searchCtrl.clear();
                            notifier.setSearch('');
                          },
                        )
                      : null,
                ),
                onChanged: notifier.setSearch,
              ),
            ),

            // ── ATK/DEF 범위 필터 ──
            _AtkDefFilterRow(
              atkMinCtrl: _atkMinCtrl,
              atkMaxCtrl: _atkMaxCtrl,
              defMinCtrl: _defMinCtrl,
              defMaxCtrl: _defMaxCtrl,
              activeFilters: state.activeFilters,
              onChanged: (key, val) => notifier.setFilter(key, val),
            ),

            // ── 선택된 카드 ──
            if (state.selectedCard != null) ...[
              const Divider(height: 1),
              _SelectedCardBar(
                card: state.selectedCard!,
                onClear: notifier.clearSelection,
                onSubmit: () => notifier.submitGuess(),
              ),
            ],

            // ── 결과 수 ──
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              child: Text(
                filtered.isEmpty
                    ? '결과 없음'
                    : hasMore
                        ? '${filtered.length}개 중 50개 표시 (필터를 좁혀보세요)'
                        : '${filtered.length}개',
                style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant),
              ),
            ),

            // ── 카드 목록 ──
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text('검색 결과가 없어요',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant)),
                    )
                  : ListView.builder(
                      itemCount: display.length + (hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == display.length) {
                          return Padding(
                            padding: const EdgeInsets.all(12),
                            child: OutlinedButton(
                              onPressed: () => setState(
                                  () => _displayCount += 50),
                              child: Text(
                                '50개 더 보기 (${filtered.length - _displayCount}개 남음)',
                              ),
                            ),
                          );
                        }
                        final card = display[index];
                        return _CardListItem(
                          card: card,
                          isSelected: state.selectedCard?.id == card.id,
                          onTap: () => notifier.selectCard(card),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// ATK/DEF range filter row
// ─────────────────────────────────────────────────────────────────

class _AtkDefFilterRow extends StatelessWidget {
  final TextEditingController atkMinCtrl;
  final TextEditingController atkMaxCtrl;
  final TextEditingController defMinCtrl;
  final TextEditingController defMaxCtrl;
  final Map<String, String?> activeFilters;
  final void Function(String key, String? val) onChanged;

  const _AtkDefFilterRow({
    required this.atkMinCtrl,
    required this.atkMaxCtrl,
    required this.defMinCtrl,
    required this.defMaxCtrl,
    required this.activeFilters,
    required this.onChanged,
  });

  void _onFieldChanged(String key, String text, String? currentVal) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      if (currentVal != null) onChanged(key, null);
    } else if (int.tryParse(trimmed) != null && trimmed != currentVal) {
      onChanged(key, trimmed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelSmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    Widget rangeField(
      TextEditingController ctrl,
      String hint,
      String filterKey,
    ) {
      return SizedBox(
        width: 72,
        child: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: hint,
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
          ),
          style: theme.textTheme.bodySmall,
          onChanged: (v) =>
              _onFieldChanged(filterKey, v, activeFilters[filterKey]),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      child: Row(
        children: [
          Text('공격력', style: labelStyle),
          const SizedBox(width: 6),
          rangeField(atkMinCtrl, '최소', 'atkMin'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text('~', style: labelStyle),
          ),
          rangeField(atkMaxCtrl, '최대', 'atkMax'),
          const SizedBox(width: 16),
          Text('수비력', style: labelStyle),
          const SizedBox(width: 6),
          rangeField(defMinCtrl, '최소', 'defMin'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text('~', style: labelStyle),
          ),
          rangeField(defMaxCtrl, '최대', 'defMax'),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Filter dropdown chip
// ─────────────────────────────────────────────────────────────────

class _FilterDropdown extends StatelessWidget {
  final String label;
  final List<(String, String)> options;
  final String? selectedRaw;
  final void Function(String?) onSelected;

  const _FilterDropdown({
    required this.label,
    required this.options,
    required this.selectedRaw,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = selectedRaw != null;

    return Container(
      decoration: BoxDecoration(
        color: isActive
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive
              ? theme.colorScheme.primary.withAlpha(160)
              : theme.colorScheme.outline.withAlpha(80),
        ),
      ),
      padding: const EdgeInsets.only(left: 10, right: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: selectedRaw,
              hint: Text(label,
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant)),
              isDense: true,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isActive
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight:
                    isActive ? FontWeight.bold : FontWeight.normal,
              ),
              icon: Icon(
                Icons.arrow_drop_down,
                size: 16,
                color: isActive
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text('전체 $label',
                      style: theme.textTheme.bodySmall),
                ),
                ...options.map((o) => DropdownMenuItem<String?>(
                      value: o.$1,
                      child: Text(o.$2,
                          style: theme.textTheme.bodySmall),
                    )),
              ],
              onChanged: onSelected,
            ),
          ),
          if (isActive) ...[
            const SizedBox(width: 2),
            GestureDetector(
              onTap: () => onSelected(null),
              child: Icon(Icons.close,
                  size: 14, color: theme.colorScheme.primary),
            ),
          ],
          const SizedBox(width: 2),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Selected card bar (inside browser)
// ─────────────────────────────────────────────────────────────────

class _SelectedCardBar extends StatelessWidget {
  final DecoderCard card;
  final VoidCallback onClear;
  final VoidCallback onSubmit;

  const _SelectedCardBar({
    required this.card,
    required this.onClear,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.primaryContainer.withAlpha(80),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            height: 46,
            child: AppNetworkImage(
              card.imageUrl,
              fit: BoxFit.contain,
              fallback: (_) =>
                  const Icon(Icons.image_not_supported, size: 18),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(card.name,
                    style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(
                  '${card.monsterTypeKr} · ${card.attributeKr} · ${card.levelRankLinkDisplay}',
                  style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: onClear,
            icon: const Icon(Icons.close, size: 16),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
          ),
          const SizedBox(width: 4),
          FilledButton(
            onPressed: onSubmit,
            style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8)),
            child: const Text('추측'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Card list item
// ─────────────────────────────────────────────────────────────────

class _CardListItem extends StatelessWidget {
  final DecoderCard card;
  final bool isSelected;
  final VoidCallback onTap;

  const _CardListItem({
    required this.card,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        color: isSelected
            ? theme.colorScheme.primaryContainer.withAlpha(150)
            : null,
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        child: Row(
          children: [
            SizedBox(
              width: 34,
              height: 48,
              child: AppNetworkImage(
                card.imageUrl,
                fit: BoxFit.contain,
                fallback: (_) =>
                    const Icon(Icons.image_not_supported, size: 18),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.name,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? theme.colorScheme.primary
                          : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${card.monsterTypeKr} · ${card.attributeKr} · ${card.levelRankLinkDisplay} · ${card.raceKr}',
                    style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle,
                  size: 16, color: theme.colorScheme.primary),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Guess table
// ─────────────────────────────────────────────────────────────────

class _GuessTable extends StatelessWidget {
  final List<GuessResult> guesses;
  const _GuessTable({required this.guesses});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('추측 기록',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _GuessTableHeader(),
                  const Divider(height: 8),
                  ...guesses.reversed
                      .map((r) => _GuessRow(result: r)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuessTableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.bold);
    return Row(
      children: [
        const SizedBox(width: 46),
        SizedBox(
            width: 110,
            child: Text('카드명', style: style)),
        ...kHintKeys.map((k) => SizedBox(
              width: 52,
              child: Text(kHintLabels[k] ?? k,
                  style: style,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            )),
      ],
    );
  }
}

class _GuessRow extends StatelessWidget {
  final GuessResult result;
  const _GuessRow({required this.result});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 36,
            height: 50,
            child: AppNetworkImage(
              result.card.imageUrl,
              fit: BoxFit.contain,
              fallback: (_) =>
                  const Icon(Icons.image_not_supported, size: 16),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 110,
            child: Text(result.card.name,
                style: theme.textTheme.labelSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ),
          ...kHintKeys.map((k) => SizedBox(
                width: 52,
                child: _JudgmentCell(
                  judgment: result.judgment(k),
                  value: result.card.hintValue(k),
                ),
              )),
        ],
      ),
    );
  }
}

class _JudgmentCell extends StatelessWidget {
  final HintJudgment judgment;
  final String value;

  const _JudgmentCell({required this.judgment, required this.value});

  @override
  Widget build(BuildContext context) {
    final (bg, icon) = switch (judgment) {
      HintJudgment.correct => (
          const Color(0xFF2E7D32),
          Icons.check_rounded
        ),
      HintJudgment.wrong => (
          const Color(0xFFB71C1C),
          Icons.close_rounded
        ),
    };

    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold)),
          Icon(icon, color: Colors.white, size: 13),
        ],
      ),
    );
  }
}
