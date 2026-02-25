import 'package:flutter/material.dart';

class Milestone {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String category;
  final int requirement;
  final int currentValue;
  final bool isEarned;

  Milestone({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.category,
    required this.requirement,
    required this.currentValue,
    required this.isEarned,
  });
}

List<Milestone> calculateMilestones({
  required Map<String, dynamic> profile,
  required List<dynamic>? completedGames,
}) {
  final totalPoints = int.tryParse(profile['TotalPoints']?.toString() ?? '0') ?? 0;
  final totalTruePoints = int.tryParse(profile['TotalTruePoints']?.toString() ?? '0') ?? 0;
  final rank = int.tryParse(profile['Rank']?.toString() ?? '0') ?? 0;

  // Count achievements from completed games
  int totalAchievements = 0;
  int masteredGames = 0;

  if (completedGames != null) {
    for (final game in completedGames) {
      final earned = game['NumAwarded'] ?? 0;
      final total = game['MaxPossible'] ?? 0;
      totalAchievements += (earned as int);
      if (earned == total && total > 0) {
        masteredGames++;
      }
    }
  }

  return [
    // Achievement milestones
    Milestone(
      id: 'ach_first',
      title: 'First Steps',
      description: 'Unlock your first achievement',
      icon: Icons.star,
      color: Colors.amber,
      category: 'Achievements',
      requirement: 1,
      currentValue: totalAchievements,
      isEarned: totalAchievements >= 1,
    ),
    Milestone(
      id: 'ach_100',
      title: 'Century',
      description: 'Unlock 100 achievements',
      icon: Icons.star,
      color: Colors.amber,
      category: 'Achievements',
      requirement: 100,
      currentValue: totalAchievements,
      isEarned: totalAchievements >= 100,
    ),
    Milestone(
      id: 'ach_500',
      title: 'Collector',
      description: 'Unlock 500 achievements',
      icon: Icons.star,
      color: Colors.amber,
      category: 'Achievements',
      requirement: 500,
      currentValue: totalAchievements,
      isEarned: totalAchievements >= 500,
    ),
    Milestone(
      id: 'ach_1000',
      title: 'Veteran',
      description: 'Unlock 1,000 achievements',
      icon: Icons.stars,
      color: Colors.amber,
      category: 'Achievements',
      requirement: 1000,
      currentValue: totalAchievements,
      isEarned: totalAchievements >= 1000,
    ),
    Milestone(
      id: 'ach_2500',
      title: 'Elite',
      description: 'Unlock 2,500 achievements',
      icon: Icons.stars,
      color: Colors.orange,
      category: 'Achievements',
      requirement: 2500,
      currentValue: totalAchievements,
      isEarned: totalAchievements >= 2500,
    ),
    Milestone(
      id: 'ach_5000',
      title: 'Legend',
      description: 'Unlock 5,000 achievements',
      icon: Icons.auto_awesome,
      color: Colors.deepOrange,
      category: 'Achievements',
      requirement: 5000,
      currentValue: totalAchievements,
      isEarned: totalAchievements >= 5000,
    ),
    Milestone(
      id: 'ach_10000',
      title: 'Mythic',
      description: 'Unlock 10,000 achievements',
      icon: Icons.auto_awesome,
      color: Colors.red,
      category: 'Achievements',
      requirement: 10000,
      currentValue: totalAchievements,
      isEarned: totalAchievements >= 10000,
    ),

    // Mastery milestones
    Milestone(
      id: 'master_first',
      title: 'Completionist',
      description: 'Master your first game',
      icon: Icons.emoji_events,
      color: Colors.purple,
      category: 'Mastery',
      requirement: 1,
      currentValue: masteredGames,
      isEarned: masteredGames >= 1,
    ),
    Milestone(
      id: 'master_5',
      title: 'Dedicated',
      description: 'Master 5 games',
      icon: Icons.emoji_events,
      color: Colors.purple,
      category: 'Mastery',
      requirement: 5,
      currentValue: masteredGames,
      isEarned: masteredGames >= 5,
    ),
    Milestone(
      id: 'master_10',
      title: 'Perfectionist',
      description: 'Master 10 games',
      icon: Icons.emoji_events,
      color: Colors.purple,
      category: 'Mastery',
      requirement: 10,
      currentValue: masteredGames,
      isEarned: masteredGames >= 10,
    ),
    Milestone(
      id: 'master_25',
      title: 'Champion',
      description: 'Master 25 games',
      icon: Icons.military_tech,
      color: Colors.deepPurple,
      category: 'Mastery',
      requirement: 25,
      currentValue: masteredGames,
      isEarned: masteredGames >= 25,
    ),
    Milestone(
      id: 'master_50',
      title: 'Grandmaster',
      description: 'Master 50 games',
      icon: Icons.military_tech,
      color: Colors.deepPurple,
      category: 'Mastery',
      requirement: 50,
      currentValue: masteredGames,
      isEarned: masteredGames >= 50,
    ),
    Milestone(
      id: 'master_100',
      title: 'Immortal',
      description: 'Master 100 games',
      icon: Icons.diamond,
      color: Colors.pink,
      category: 'Mastery',
      requirement: 100,
      currentValue: masteredGames,
      isEarned: masteredGames >= 100,
    ),

    // Points milestones
    Milestone(
      id: 'pts_1k',
      title: 'Rising Star',
      description: 'Earn 1,000 points',
      icon: Icons.trending_up,
      color: Colors.green,
      category: 'Points',
      requirement: 1000,
      currentValue: totalPoints,
      isEarned: totalPoints >= 1000,
    ),
    Milestone(
      id: 'pts_5k',
      title: 'Skilled',
      description: 'Earn 5,000 points',
      icon: Icons.trending_up,
      color: Colors.green,
      category: 'Points',
      requirement: 5000,
      currentValue: totalPoints,
      isEarned: totalPoints >= 5000,
    ),
    Milestone(
      id: 'pts_10k',
      title: 'Expert',
      description: 'Earn 10,000 points',
      icon: Icons.show_chart,
      color: Colors.teal,
      category: 'Points',
      requirement: 10000,
      currentValue: totalPoints,
      isEarned: totalPoints >= 10000,
    ),
    Milestone(
      id: 'pts_25k',
      title: 'Master',
      description: 'Earn 25,000 points',
      icon: Icons.show_chart,
      color: Colors.teal,
      category: 'Points',
      requirement: 25000,
      currentValue: totalPoints,
      isEarned: totalPoints >= 25000,
    ),
    Milestone(
      id: 'pts_50k',
      title: 'Prodigy',
      description: 'Earn 50,000 points',
      icon: Icons.insights,
      color: Colors.cyan,
      category: 'Points',
      requirement: 50000,
      currentValue: totalPoints,
      isEarned: totalPoints >= 50000,
    ),
    Milestone(
      id: 'pts_100k',
      title: 'Titan',
      description: 'Earn 100,000 points',
      icon: Icons.insights,
      color: Colors.blue,
      category: 'Points',
      requirement: 100000,
      currentValue: totalPoints,
      isEarned: totalPoints >= 100000,
    ),

    // Rank milestones
    if (rank > 0 && rank <= 10000)
      Milestone(
        id: 'rank_10k',
        title: 'Top 10,000',
        description: 'Reach top 10,000 globally',
        icon: Icons.leaderboard,
        color: Colors.indigo,
        category: 'Rank',
        requirement: 10000,
        currentValue: rank,
        isEarned: rank <= 10000,
      ),
    if (rank > 0 && rank <= 5000)
      Milestone(
        id: 'rank_5k',
        title: 'Top 5,000',
        description: 'Reach top 5,000 globally',
        icon: Icons.leaderboard,
        color: Colors.indigo,
        category: 'Rank',
        requirement: 5000,
        currentValue: rank,
        isEarned: rank <= 5000,
      ),
    if (rank > 0 && rank <= 1000)
      Milestone(
        id: 'rank_1k',
        title: 'Top 1,000',
        description: 'Reach top 1,000 globally',
        icon: Icons.workspace_premium,
        color: Colors.amber,
        category: 'Rank',
        requirement: 1000,
        currentValue: rank,
        isEarned: rank <= 1000,
      ),
    if (rank > 0 && rank <= 500)
      Milestone(
        id: 'rank_500',
        title: 'Top 500',
        description: 'Reach top 500 globally',
        icon: Icons.workspace_premium,
        color: Colors.orange,
        category: 'Rank',
        requirement: 500,
        currentValue: rank,
        isEarned: rank <= 500,
      ),
    if (rank > 0 && rank <= 100)
      Milestone(
        id: 'rank_100',
        title: 'Top 100',
        description: 'Reach top 100 globally',
        icon: Icons.diamond,
        color: Colors.red,
        category: 'Rank',
        requirement: 100,
        currentValue: rank,
        isEarned: rank <= 100,
      ),

    // RetroPoints milestones
    Milestone(
      id: 'true_10k',
      title: 'Retro Gamer',
      description: 'Earn 10,000 RetroPoints',
      icon: Icons.verified,
      color: Colors.blue,
      category: 'RetroPoints',
      requirement: 10000,
      currentValue: totalTruePoints,
      isEarned: totalTruePoints >= 10000,
    ),
    Milestone(
      id: 'true_50k',
      title: 'Retro Master',
      description: 'Earn 50,000 RetroPoints',
      icon: Icons.verified,
      color: Colors.blue,
      category: 'RetroPoints',
      requirement: 50000,
      currentValue: totalTruePoints,
      isEarned: totalTruePoints >= 50000,
    ),
    Milestone(
      id: 'true_100k',
      title: 'Retro Legend',
      description: 'Earn 100,000 RetroPoints',
      icon: Icons.verified,
      color: Colors.lightBlue,
      category: 'RetroPoints',
      requirement: 100000,
      currentValue: totalTruePoints,
      isEarned: totalTruePoints >= 100000,
    ),
  ];
}
