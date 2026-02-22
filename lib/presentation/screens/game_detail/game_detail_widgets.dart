import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme_utils.dart';
import '../../../core/animations.dart';
import '../../providers/favorites_provider.dart';
import 'game_detail_helpers.dart';

export 'game_detail_helpers.dart';

class GameFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  const GameFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? Colors.blue;
    return GestureDetector(
      onTap: () {
        Haptics.selection();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? chipColor.withValues(alpha: 0.2) : Colors.transparent,
          border: Border.all(
            color: selected ? chipColor : Colors.grey[600]!,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? chipColor : Colors.grey[400],
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}


class DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const DetailRow(this.icon, this.label, this.value);

  Color _getColor() {
    switch (label) {
      case 'Developer':
        return Colors.blue;
      case 'Publisher':
        return Colors.purple;
      case 'Genre':
        return Colors.teal;
      case 'Released':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                value,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class FavoriteButtonLarge extends ConsumerWidget {
  final int gameId;
  final String title;
  final String imageIcon;
  final String consoleName;
  final int numAchievements;
  final int earnedAchievements;
  final int totalPoints;
  final int earnedPoints;

  const FavoriteButtonLarge({
    required this.gameId,
    required this.title,
    required this.imageIcon,
    required this.consoleName,
    required this.numAchievements,
    required this.earnedAchievements,
    required this.totalPoints,
    required this.earnedPoints,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavorite = ref.watch(favoritesProvider).isFavorite(gameId);

    return isFavorite
        ? FilledButton.icon(
            onPressed: () => _toggleFavorite(context, ref, isFavorite),
            icon: const Icon(Icons.star, size: 18),
            label: const Text('Favorited'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
          )
        : OutlinedButton.icon(
            onPressed: () => _toggleFavorite(context, ref, isFavorite),
            icon: const Icon(Icons.star_border, size: 18),
            label: const Text('Favorite'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
          );
  }

  void _toggleFavorite(BuildContext context, WidgetRef ref, bool isFavorite) {
    Haptics.medium();
    final game = FavoriteGame(
      gameId: gameId,
      title: title,
      imageIcon: imageIcon,
      consoleName: consoleName,
      numAchievements: numAchievements,
      earnedAchievements: earnedAchievements,
      totalPoints: totalPoints,
      earnedPoints: earnedPoints,
      addedAt: DateTime.now(),
    );
    ref.read(favoritesProvider.notifier).toggleFavorite(game);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isFavorite ? 'Removed from favorites' : 'Added to favorites'),
        duration: const Duration(seconds: 1),
      ),
    );
  }
}


class FavoriteIconButton extends ConsumerWidget {
  final int gameId;
  final String title;
  final String imageIcon;
  final String consoleName;
  final int numAchievements;
  final int earnedAchievements;
  final int totalPoints;
  final int earnedPoints;

  const FavoriteIconButton({
    super.key,
    required this.gameId,
    required this.title,
    required this.imageIcon,
    required this.consoleName,
    required this.numAchievements,
    required this.earnedAchievements,
    required this.totalPoints,
    required this.earnedPoints,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavorite = ref.watch(favoritesProvider).isFavorite(gameId);

    return GestureDetector(
      onTap: () => _toggleFavorite(context, ref, isFavorite),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isFavorite
              ? Colors.amber.withValues(alpha: 0.2)
              : Colors.grey.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          isFavorite ? Icons.star : Icons.star_border,
          size: 18,
          color: isFavorite ? Colors.amber : Colors.grey,
        ),
      ),
    );
  }

  void _toggleFavorite(BuildContext context, WidgetRef ref, bool isFavorite) {
    Haptics.medium();
    final game = FavoriteGame(
      gameId: gameId,
      title: title,
      imageIcon: imageIcon,
      consoleName: consoleName,
      numAchievements: numAchievements,
      earnedAchievements: earnedAchievements,
      totalPoints: totalPoints,
      earnedPoints: earnedPoints,
      addedAt: DateTime.now(),
    );
    ref.read(favoritesProvider.notifier).toggleFavorite(game);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isFavorite ? 'Removed from favorites' : 'Added to favorites'),
        duration: const Duration(seconds: 1),
      ),
    );
  }
}


class AnimatedRarityDistribution extends StatefulWidget {
  final int ultraRareCount;
  final int rareCount;
  final int uncommonCount;
  final int commonCount;
  final int numDistinctPlayers;

  const AnimatedRarityDistribution({
    required this.ultraRareCount,
    required this.rareCount,
    required this.uncommonCount,
    required this.commonCount,
    required this.numDistinctPlayers,
  });

  @override
  State<AnimatedRarityDistribution> createState() => AnimatedRarityDistributionState();
}

class AnimatedRarityDistributionState extends State<AnimatedRarityDistribution>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    // Start animation after a small delay for smoother page load
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.ultraRareCount + widget.rareCount + widget.uncommonCount + widget.commonCount;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.light
            ? Colors.grey.shade100
            : Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.bar_chart, size: 16, color: Colors.purple),
              const SizedBox(width: 6),
              Text(
                'Rarity Distribution',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: context.subtitleColor,
                ),
              ),
              const Spacer(),
              Text(
                '${widget.numDistinctPlayers} players',
                style: TextStyle(fontSize: 10, color: context.subtitleColor),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Animated stacked bar chart
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 24,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final maxWidth = constraints.maxWidth;
                      final animValue = _animation.value;

                      return Stack(
                        children: [
                          // Background
                          Container(
                            width: maxWidth,
                            color: Colors.grey.withValues(alpha: 0.2),
                          ),
                          // Animated bars
                          Row(
                            children: [
                              if (widget.ultraRareCount > 0)
                                _buildAnimatedBar(
                                  width: (widget.ultraRareCount / total) * maxWidth * animValue,
                                  color: Colors.red,
                                  count: widget.ultraRareCount,
                                  animValue: animValue,
                                ),
                              if (widget.rareCount > 0)
                                _buildAnimatedBar(
                                  width: (widget.rareCount / total) * maxWidth * animValue,
                                  color: Colors.purple,
                                  count: widget.rareCount,
                                  animValue: animValue,
                                ),
                              if (widget.uncommonCount > 0)
                                _buildAnimatedBar(
                                  width: (widget.uncommonCount / total) * maxWidth * animValue,
                                  color: Colors.blue,
                                  count: widget.uncommonCount,
                                  animValue: animValue,
                                ),
                              if (widget.commonCount > 0)
                                _buildAnimatedBar(
                                  width: (widget.commonCount / total) * maxWidth * animValue,
                                  color: Colors.blueGrey,
                                  count: widget.commonCount,
                                  animValue: animValue,
                                ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          // Legend with counts
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _buildLegendItem(Icons.diamond, Colors.red, 'Ultra Rare', '<5%', widget.ultraRareCount),
              _buildLegendItem(Icons.star, Colors.purple, 'Rare', '<15%', widget.rareCount),
              _buildLegendItem(Icons.hexagon, Colors.blue, 'Uncommon', '<40%', widget.uncommonCount),
              _buildLegendItem(Icons.circle, Colors.blueGrey, 'Common', '40%+', widget.commonCount),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedBar({
    required double width,
    required Color color,
    required int count,
    required double animValue,
  }) {
    return Container(
      width: width,
      height: 24,
      color: color,
      child: Center(
        child: animValue > 0.7 && count >= 3
            ? Opacity(
                opacity: ((animValue - 0.7) / 0.3).clamp(0.0, 1.0),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildLegendItem(IconData icon, Color color, String name, String percent, int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: color),
        const SizedBox(width: 3),
        Text(
          '$name ($count)',
          style: TextStyle(fontSize: 10, color: context.subtitleColor),
        ),
      ],
    );
  }
}


class UserGameRankCard extends StatelessWidget {
  final Map<String, dynamic> rankData;

  const UserGameRankCard({super.key, required this.rankData});

  @override
  Widget build(BuildContext context) {
    final rank = rankData['Rank'] ?? rankData['UserRank'] ?? 0;
    final score = rankData['Score'] ?? rankData['TotalScore'] ?? 0;
    final totalRanked = rankData['TotalRanked'] ?? rankData['NumEntries'] ?? 0;

    if (rank == 0 && score == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.amber.withValues(alpha: 0.15),
            Colors.orange.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '#$rank',
                style: const TextStyle(
                  color: Colors.amber,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Rank',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  totalRanked > 0
                      ? 'Rank $rank of $totalRanked players'
                      : 'Rank #$rank',
                  style: TextStyle(color: context.subtitleColor, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.stars, size: 14, color: Colors.amber),
                const SizedBox(width: 4),
                Text(
                  '$score',
                  style: const TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class SortMenuButton extends StatelessWidget {
  final AchievementSort currentSort;
  final ValueChanged<AchievementSort> onSortChanged;

  const SortMenuButton({
    super.key,
    required this.currentSort,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<AchievementSort>(
      onSelected: onSortChanged,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[600]!),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sort, size: 14),
            const SizedBox(width: 4),
            Text(getSortLabel(currentSort), style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
      itemBuilder: (ctx) => [
        _buildSortItem(AchievementSort.normal, 'Default'),
        _buildSortItem(AchievementSort.points, 'Points'),
        _buildSortItem(AchievementSort.rarity, 'Rarity'),
        _buildSortItem(AchievementSort.title, 'Title'),
      ],
    );
  }

  PopupMenuItem<AchievementSort> _buildSortItem(AchievementSort value, String label) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          if (currentSort == value) const Icon(Icons.check, size: 18) else const SizedBox(width: 18),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}


class NoMissableMessage extends StatelessWidget {
  const NoMissableMessage({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(Icons.info_outline, size: 48, color: Colors.grey[600]),
          const SizedBox(height: 16),
          Text(
            'No missable achievements found',
            style: TextStyle(color: context.subtitleColor, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'This game may not have any achievements marked as missable by the developers.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.subtitleColor, fontSize: 13),
          ),
        ],
      ),
    );
  }
}


class GameDetailShimmer extends StatelessWidget {
  final bool transitionComplete;

  const GameDetailShimmer({super.key, required this.transitionComplete});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final placeholderColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;

    if (!transitionComplete) {
      return CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(color: placeholderColor),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                height: 180,
                decoration: BoxDecoration(
                  color: placeholderColor,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 200,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            background: ShimmerCard(
              height: 200,
              borderRadius: 0,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ShimmerCard(height: 180),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ShimmerCard(height: 40, width: 150),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ShimmerAchievementTile(),
            ),
            childCount: 8,
          ),
        ),
      ],
    );
  }
}


class AchievementStatsRow extends StatelessWidget {
  final int numAwarded;
  final int totalAchievements;
  final int earnedPoints;
  final int totalPoints;
  final int filteredCount;

  const AchievementStatsRow({
    super.key,
    required this.numAwarded,
    required this.totalAchievements,
    required this.earnedPoints,
    required this.totalPoints,
    required this.filteredCount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$numAwarded/$totalAchievements',
            style: const TextStyle(color: Colors.green, fontSize: 11),
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.star, size: 12, color: Colors.amber[700]),
              const SizedBox(width: 3),
              Text(
                '$earnedPoints/$totalPoints pts',
                style: TextStyle(color: Colors.amber[700], fontSize: 11),
              ),
            ],
          ),
        ),
        const Spacer(),
        Text(
          'Showing $filteredCount',
          style: TextStyle(color: context.subtitleColor, fontSize: 11),
        ),
      ],
    );
  }
}


/// Mastery badge shown when all achievements are completed
class MasteryBadge extends StatelessWidget {
  final MasteryInfo masteryInfo;

  const MasteryBadge({super.key, required this.masteryInfo});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.amber.withValues(alpha: 0.2),
            Colors.orange.withValues(alpha: 0.15),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.amber.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withValues(alpha: isDark ? 0.15 : 0.1),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.amber, Colors.orange.shade600],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withValues(alpha: 0.4),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: const Icon(
              Icons.military_tech,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Colors.amber, Colors.orange],
                      ).createShader(bounds),
                      child: const Text(
                        'MASTERED',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.verified, size: 16, color: Colors.amber),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Completed in ${masteryInfo.formattedDuration}',
                  style: TextStyle(
                    color: isDark ? Colors.amber[200] : Colors.amber[800],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.emoji_events, size: 16, color: Colors.amber),
                const SizedBox(width: 4),
                const Text(
                  '100%',
                  style: TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
