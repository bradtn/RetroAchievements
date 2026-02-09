import 'package:flutter/material.dart';

enum AchievementFilter { all, earned, unearned }
enum AchievementSort { normal, points, rarity, title }

/// Get the sort label for display
String getSortLabel(AchievementSort sort) {
  switch (sort) {
    case AchievementSort.normal: return 'Default';
    case AchievementSort.points: return 'Points';
    case AchievementSort.rarity: return 'Rarity';
    case AchievementSort.title: return 'Title';
  }
}

/// Calculate rarity tier for an achievement
Map<String, dynamic> getRarityTier(int numAwarded, int numDistinct) {
  if (numDistinct > 0) {
    final percent = (numAwarded / numDistinct) * 100;
    if (percent < 5) return {'label': 'Ultra Rare', 'color': Colors.red, 'icon': Icons.diamond, 'tier': 0};
    if (percent < 15) return {'label': 'Rare', 'color': Colors.purple, 'icon': Icons.star, 'tier': 1};
    if (percent < 40) return {'label': 'Uncommon', 'color': Colors.blue, 'icon': Icons.hexagon, 'tier': 2};
    return {'label': 'Common', 'color': Colors.grey, 'icon': Icons.circle, 'tier': 3};
  }
  // Fallback to absolute numbers
  if (numAwarded < 100) return {'label': 'Ultra Rare', 'color': Colors.red, 'icon': Icons.diamond, 'tier': 0};
  if (numAwarded < 500) return {'label': 'Rare', 'color': Colors.purple, 'icon': Icons.star, 'tier': 1};
  if (numAwarded < 2000) return {'label': 'Uncommon', 'color': Colors.blue, 'icon': Icons.hexagon, 'tier': 2};
  return {'label': 'Common', 'color': Colors.grey, 'icon': Icons.circle, 'tier': 3};
}

/// Filter and sort achievements based on filter/sort state
List<Map<String, dynamic>> getFilteredAchievements(
  Map<String, dynamic> achievements,
  AchievementFilter filter,
  AchievementSort sort,
  bool showMissable,
) {
  var list = achievements.values.cast<Map<String, dynamic>>().toList();

  // Filter by earned/unearned
  if (filter == AchievementFilter.earned) {
    list = list.where((a) => a['DateEarned'] != null || a['DateEarnedHardcore'] != null).toList();
  } else if (filter == AchievementFilter.unearned) {
    list = list.where((a) => a['DateEarned'] == null && a['DateEarnedHardcore'] == null).toList();
  }

  // Filter by missable achievements
  if (showMissable) {
    list = list.where((a) {
      final type = (a['Type'] ?? a['type'] ?? '').toString().toLowerCase();
      final flags = a['Flags'] ?? a['flags'] ?? 0;
      final isMissable = type == 'missable' ||
                        type.contains('missable') ||
                        flags == 4 ||
                        (flags is int && (flags & 4) != 0);
      return isMissable;
    }).toList();
  }

  // Sort
  switch (sort) {
    case AchievementSort.points:
      list.sort((a, b) => (b['Points'] ?? 0).compareTo(a['Points'] ?? 0));
      break;
    case AchievementSort.rarity:
      list.sort((a, b) => (a['NumAwarded'] ?? 0).compareTo(b['NumAwarded'] ?? 0));
      break;
    case AchievementSort.title:
      list.sort((a, b) => (a['Title'] ?? '').compareTo(b['Title'] ?? ''));
      break;
    case AchievementSort.normal:
      break;
  }

  return list;
}

/// Calculate rarity distribution counts for a set of achievements
RarityDistributionCounts calculateRarityDistribution(
  Map<String, dynamic> achievements,
  int numDistinctPlayers,
) {
  int ultraRareCount = 0;
  int rareCount = 0;
  int uncommonCount = 0;
  int commonCount = 0;

  for (final entry in achievements.entries) {
    final ach = entry.value as Map<String, dynamic>;
    final numAwarded = ach['NumAwarded'] ?? 0;
    final tier = getRarityTier(numAwarded, numDistinctPlayers);
    switch (tier['tier'] as int) {
      case 0: ultraRareCount++; break;
      case 1: rareCount++; break;
      case 2: uncommonCount++; break;
      case 3: commonCount++; break;
    }
  }

  return RarityDistributionCounts(
    ultraRare: ultraRareCount,
    rare: rareCount,
    uncommon: uncommonCount,
    common: commonCount,
  );
}

class RarityDistributionCounts {
  final int ultraRare;
  final int rare;
  final int uncommon;
  final int common;

  const RarityDistributionCounts({
    required this.ultraRare,
    required this.rare,
    required this.uncommon,
    required this.common,
  });
}

/// Calculate total and earned points from achievements
({int totalPoints, int earnedPoints}) calculatePoints(Map<String, dynamic> achievements) {
  int totalPoints = 0;
  int earnedPoints = 0;

  for (final entry in achievements.entries) {
    final ach = entry.value as Map<String, dynamic>;
    final pts = ach['Points'] ?? 0;
    final pointValue = (pts is int) ? pts : int.tryParse(pts.toString()) ?? 0;
    totalPoints += pointValue;
    final dateEarned = ach['DateEarned'] ?? ach['DateEarnedHardcore'];
    if (dateEarned != null && dateEarned.toString().isNotEmpty) {
      earnedPoints += pointValue;
    }
  }

  return (totalPoints: totalPoints, earnedPoints: earnedPoints);
}
