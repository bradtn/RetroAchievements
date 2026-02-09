import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme_utils.dart';
import '../../../core/animations.dart';
import '../../providers/favorites_provider.dart';

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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(color: Colors.grey)),
          Expanded(child: Text(value)),
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
                                  color: Colors.grey,
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
              _buildLegendItem(Icons.circle, Colors.grey, 'Common', '40%+', widget.commonCount),
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
