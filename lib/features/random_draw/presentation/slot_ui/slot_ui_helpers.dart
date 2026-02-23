import 'package:flutter/material.dart';

import '../../domain/daily_slot_rule.dart';


// -----------------------------
// Pretty label (UI helper)
// -----------------------------
String prettyCategory(String key) {
  final raw = key.trim();
  if (raw.isEmpty) return raw;

  if (!raw.contains(':')) {
    if (raw.startsWith('Lv')) return '레벨 ${raw.substring(2)}';
    if (raw == 'Spell') return '마법';
    if (raw == 'Trap') return '함정';
    if (raw == 'Quick-Play') return '속공';
    if (raw == 'Continuous') return '지속';
    if (raw == 'Counter') return '카운터';
    return raw;
  }

  final parts = raw.split(':');
  final kind = parts[0];
  final val = parts.sublist(1).join(':');

  switch (kind) {
    case 'lv':
      return '레벨 $val';

    case 'attr':
      switch (val) {
        case 'dark':
          return '어둠';
        case 'light':
          return '빛';
        case 'water':
          return '물';
        case 'fire':
          return '불';
        case 'wind':
          return '바람';
        case 'earth':
          return '땅';
        case 'divine':
          return '신';
        default:
          return val.toUpperCase();
      }

    case 'race':
      return '종족 ${_titleCase(val)}';

    case 'sub':
      if (val == 'quick-play') return '속공 마법';
      if (val == 'continuous') return '지속 (마/함)';
      if (val == 'counter') return '카운터 함정';
      return '특성 ${_titleCase(val)}';

    case 'extra':
      if (val == 'fusion') return '융합';
      if (val == 'synchro') return '싱크로';
      if (val == 'xyz') return '엑시즈';
      if (val == 'link') return '링크';
      return '엑스트라 ${_titleCase(val)}';

    case 'atk':
      if (val == '0-1500') return 'ATK 0~1500';
      if (val == '1501-2500') return 'ATK 1501~2500';
      if (val == '2501+') return 'ATK 2501+';
      return 'ATK $val';
  }

  return raw;
}

String _titleCase(String s) {
  if (s.isEmpty) return s;
  final parts = s.split(RegExp(r'[\s\-_]+'));
  return parts
      .where((e) => e.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');
}

// -----------------------------
// Difficulty badge (UI helper)
// -----------------------------
enum SlotDifficulty { easy, medium, hard }

SlotDifficulty difficultyForCategoryKey(String key) {
  final raw = key.trim();

  if (!raw.contains(':')) {
    if (raw.startsWith('Lv')) return SlotDifficulty.easy;
    if (raw == 'Spell' || raw == 'Trap') return SlotDifficulty.easy;
    if (raw == 'Quick-Play') return SlotDifficulty.medium;
    if (raw == 'Continuous') return SlotDifficulty.medium;
    if (raw == 'Counter') return SlotDifficulty.hard;
    return SlotDifficulty.medium;
  }

  final kind = raw.split(':').first;
  switch (kind) {
    case 'lv':
      return SlotDifficulty.easy;
    case 'atk':
      return SlotDifficulty.medium;
    case 'attr':
      return SlotDifficulty.medium;
    case 'race':
      return SlotDifficulty.medium;
    case 'sub':
      return SlotDifficulty.hard;
    case 'extra':
      return SlotDifficulty.hard;
    default:
      return SlotDifficulty.medium;
  }
}

String difficultyBadgeText(SlotDifficulty d) {
  switch (d) {
    case SlotDifficulty.easy:
      return 'E';
    case SlotDifficulty.medium:
      return 'M';
    case SlotDifficulty.hard:
      return 'H';
  }
}

// -----------------------------
// Day kind (label/icon/chip colors)
// -----------------------------
String dayKindLabel(DayKind k) {
  switch (k) {
    case DayKind.normal:
      return '일반';
    case DayKind.spotlight:
      return '스포트라이트';
    case DayKind.boss:
      return '보스';
  }
}

IconData dayKindIcon(DayKind k) {
  switch (k) {
    case DayKind.normal:
      return Icons.grid_view_rounded;
    case DayKind.spotlight:
      return Icons.flash_on_rounded;
    case DayKind.boss:
      return Icons.emoji_events_rounded;
  }
}

Color dayKindChipBg(ThemeData theme, DayKind k) {
  switch (k) {
    case DayKind.normal:
      return theme.colorScheme.surfaceContainerHighest;
    case DayKind.spotlight:
      return theme.colorScheme.secondaryContainer;
    case DayKind.boss:
      return theme.colorScheme.primary;
  }
}

Color dayKindChipFg(ThemeData theme, DayKind k) {
  switch (k) {
    case DayKind.normal:
      return theme.colorScheme.onSurfaceVariant;
    case DayKind.spotlight:
      return theme.colorScheme.onSecondaryContainer;
    case DayKind.boss:
      return theme.colorScheme.onPrimary;
  }
}

Color dayKindChipBorder(ThemeData theme, DayKind k) {
  switch (k) {
    case DayKind.normal:
      return theme.dividerColor;
    case DayKind.spotlight:
      return theme.colorScheme.secondary.withAlpha(80);
    case DayKind.boss:
      return Colors.transparent;
  }
}
