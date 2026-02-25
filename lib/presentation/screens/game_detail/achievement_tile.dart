import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme_utils.dart';
import '../../../core/animations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/premium_provider.dart';
import '../../providers/comment_count_provider.dart';
import '../share_card/share_card_screen.dart';

class AchievementTile extends ConsumerWidget {
  final Map<String, dynamic> achievement;
  final int numDistinctPlayers;
  final String? gameTitle;
  final String? gameIcon;
  final String? consoleName;
  final String? username;
  final String? userPic;
  final bool compact;

  const AchievementTile({
    super.key,
    required this.achievement,
    this.numDistinctPlayers = 0,
    this.gameTitle,
    this.gameIcon,
    this.consoleName,
    this.username,
    this.userPic,
    this.compact = false,
  });

  // Get rarity info based on NumAwarded (how many players unlocked it)
  // Lower number = rarer achievement
  Map<String, dynamic> _getRarityInfo(int numAwarded, int numDistinct) {
    // Calculate percentage of players who earned this achievement
    // numDistinct = total distinct players for this game
    if (numDistinct > 0) {
      final percent = (numAwarded / numDistinct) * 100;
      if (percent < 5) return {'label': 'Ultra Rare', 'color': Colors.red, 'icon': Icons.diamond};
      if (percent < 15) return {'label': 'Rare', 'color': Colors.purple, 'icon': Icons.star};
      if (percent < 40) return {'label': 'Uncommon', 'color': Colors.blue, 'icon': Icons.hexagon};
      return {'label': 'Common', 'color': Colors.blueGrey, 'icon': Icons.circle};
    }
    // Fallback to absolute numbers if no player count
    if (numAwarded < 100) return {'label': 'Ultra Rare', 'color': Colors.red, 'icon': Icons.diamond};
    if (numAwarded < 500) return {'label': 'Rare', 'color': Colors.purple, 'icon': Icons.star};
    if (numAwarded < 2000) return {'label': 'Uncommon', 'color': Colors.blue, 'icon': Icons.hexagon};
    return {'label': 'Common', 'color': Colors.blueGrey, 'icon': Icons.circle};
  }

  // Check if achievement is missable
  bool _isMissable(Map<String, dynamic> achievement) {
    final type = (achievement['Type'] ?? achievement['type'] ?? '').toString().toLowerCase();
    final flags = achievement['Flags'] ?? achievement['flags'] ?? 0;
    return type == 'missable' ||
           type.contains('missable') ||
           flags == 4 ||
           (flags is int && (flags & 4) != 0);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = achievement['Title'] ?? 'Achievement';
    final description = achievement['Description'] ?? '';
    final points = achievement['Points'] ?? 0;
    final badgeName = achievement['BadgeName'] ?? '';
    final numAwarded = achievement['NumAwarded'] ?? 0;
    final isPremium = ref.watch(isPremiumProvider);
    final isMissable = _isMissable(achievement);
    final achievementId = achievement['ID'] ?? 0;

    // Watch comment count from cache
    final commentCounts = ref.watch(commentCountCacheProvider);
    final cachedCommentCount = achievementId > 0 ? commentCounts[achievementId] : null;

    final rarityInfo = _getRarityInfo(numAwarded, numDistinctPlayers);

    // Calculate unlock percentage
    final unlockPercent = numDistinctPlayers > 0
        ? (numAwarded / numDistinctPlayers * 100)
        : 0.0;

    final dateEarned = achievement['DateEarned'] ?? achievement['DateEarnedHardcore'];
    final isEarned = dateEarned != null;

    // Sizing based on compact mode
    final badgeSize = compact ? 36.0 : 52.0;
    final cardPadding = compact ? 8.0 : 12.0;
    final cardMargin = compact
        ? const EdgeInsets.symmetric(horizontal: 4, vertical: 2)
        : const EdgeInsets.symmetric(horizontal: 16, vertical: 4);

    return Card(
      margin: cardMargin,
      child: InkWell(
        onTap: () {
          Haptics.light();
          _showAchievementDetail(context, ref);
        },
        borderRadius: BorderRadius.circular(compact ? 8 : 12),
        child: Padding(
          padding: EdgeInsets.all(cardPadding),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Achievement badge with earned indicator
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(compact ? 6 : 8),
                    child: ColorFiltered(
                      colorFilter: isEarned
                          ? const ColorFilter.mode(Colors.transparent, BlendMode.dst)
                          : const ColorFilter.matrix(<double>[
                              0.2126, 0.7152, 0.0722, 0, 0,
                              0.2126, 0.7152, 0.0722, 0, 0,
                              0.2126, 0.7152, 0.0722, 0, 0,
                              0, 0, 0, 0.6, 0,
                            ]),
                      child: CachedNetworkImage(
                        imageUrl: 'https://retroachievements.org/Badge/$badgeName.png',
                        width: badgeSize,
                        height: badgeSize,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          width: badgeSize, height: badgeSize,
                          color: Colors.grey[800],
                          child: Icon(Icons.emoji_events, size: compact ? 16 : 24),
                        ),
                      ),
                    ),
                  ),
                  if (isEarned)
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        padding: EdgeInsets.all(compact ? 1 : 2),
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.check, color: Colors.white, size: compact ? 8 : 12),
                      ),
                    ),
                ],
              ),
              SizedBox(width: compact ? 8 : 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title row with points badge
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isEarned ? null : context.subtitleColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star, size: 10, color: Colors.amber),
                              const SizedBox(width: 2),
                              Text(
                                '$points',
                                style: TextStyle(color: Colors.amber[400], fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Description
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.subtitleColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Rarity progress bar (always visible)
                    _buildRarityBar(context, unlockPercent, rarityInfo, isPremium),
                    const SizedBox(height: 6),
                    // Badges row
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        // Rarity label badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (rarityInfo['color'] as Color).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: (rarityInfo['color'] as Color).withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(rarityInfo['icon'] as IconData, size: 10, color: rarityInfo['color'] as Color),
                              const SizedBox(width: 3),
                              Text(
                                rarityInfo['label'] as String,
                                style: TextStyle(color: rarityInfo['color'] as Color, fontSize: 9, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        // Unlock count badge
                        if (numAwarded > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.cyan.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: Colors.cyan.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.people, size: 10, color: Colors.cyan[600]),
                                const SizedBox(width: 3),
                                Text(
                                  _formatUnlockCount(numAwarded),
                                  style: TextStyle(color: Colors.cyan[600], fontSize: 9, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        // Missable badge
                        if (isMissable)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.red.withValues(alpha: 0.3), width: 1),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.warning_amber_rounded, size: 10, color: Colors.red),
                                SizedBox(width: 3),
                                Text(
                                  'Missable',
                                  style: TextStyle(color: Colors.red, fontSize: 9, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        // Tips badge - always show lightbulb, add count when loaded
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (cachedCommentCount != null && cachedCommentCount > 0)
                                ? Colors.amber.withValues(alpha: 0.15)
                                : Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: (cachedCommentCount != null && cachedCommentCount > 0)
                                  ? Colors.amber.withValues(alpha: 0.3)
                                  : Colors.grey.withValues(alpha: 0.2),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                (cachedCommentCount != null && cachedCommentCount > 0)
                                    ? Icons.lightbulb
                                    : Icons.lightbulb_outline,
                                size: 10,
                                color: (cachedCommentCount != null && cachedCommentCount > 0)
                                    ? Colors.amber
                                    : Colors.grey,
                              ),
                              if (cachedCommentCount != null && cachedCommentCount > 0) ...[
                                const SizedBox(width: 3),
                                Text(
                                  '$cachedCommentCount',
                                  style: const TextStyle(color: Colors.amber, fontSize: 9, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRarityBar(BuildContext context, double unlockPercent, Map<String, dynamic> rarityInfo, bool isPremium) {
    final color = rarityInfo['color'] as Color;
    // Clamp percentage for bar display (0-100)
    final barPercent = unlockPercent.clamp(0.0, 100.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Progress bar
        Stack(
          children: [
            // Background
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            // Filled portion
            FractionallySizedBox(
              widthFactor: barPercent / 100,
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withValues(alpha: 0.7)],
                  ),
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.4),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        // Percentage label
        Row(
          children: [
            Text(
              numDistinctPlayers > 0
                  ? '${unlockPercent.toStringAsFixed(1)}% of players'
                  : 'Unlock rate unavailable',
              style: TextStyle(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatUnlockCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M unlocks';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K unlocks';
    }
    return '$count unlocks';
  }

  void _showAchievementDetail(BuildContext context, WidgetRef ref) async {
    final title = achievement['Title'] ?? 'Achievement';
    final description = achievement['Description'] ?? '';
    final points = achievement['Points'] ?? 0;
    final badgeName = achievement['BadgeName'] ?? '';
    final numAwarded = achievement['NumAwarded'] ?? 0;
    final dateEarned = achievement['DateEarned'] ?? achievement['DateEarnedHardcore'];
    final isEarned = dateEarned != null;
    final rarityInfo = _getRarityInfo(numAwarded, numDistinctPlayers);
    final unlockPercent = numDistinctPlayers > 0
        ? (numAwarded / numDistinctPlayers * 100)
        : 0.0;
    final isMissable = _isMissable(achievement);
    final achievementId = achievement['ID'] ?? 0;

    final api = ref.read(apiDataSourceProvider);
    final commentNotifier = ref.read(commentCountCacheProvider.notifier);

    // Fetch user profile and comment count in parallel
    String? fetchedUserPic = userPic;
    int commentCount = 0;

    final results = await Future.wait([
      // Fetch user profile if needed
      (fetchedUserPic == null || fetchedUserPic.isEmpty)
          ? api.getUserProfile(username ?? '')
          : Future.value(null),
      // Fetch comment count (uses cache if available)
      achievementId > 0
          ? commentNotifier.fetchSingle(achievementId)
          : Future.value(null),
    ]);

    if (fetchedUserPic == null || fetchedUserPic.isEmpty) {
      final profile = results[0] as Map<String, dynamic>?;
      fetchedUserPic = profile?['UserPic'] ?? '';
    }

    final fetchedCount = results[1] as int?;
    commentCount = fetchedCount ?? 0;

    if (!context.mounted) return;

    // Show dialog and update cache AFTER it closes so the tile rebuilds
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340, maxHeight: 480),
          child: Stack(
            children: [
              SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 40, 16, 16), // Compact padding
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Achievement badge with earned/locked state
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                if (isEarned)
                                  BoxShadow(
                                    color: Colors.amber.withValues(alpha: 0.4),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                  ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: ColorFiltered(
                                colorFilter: isEarned
                                    ? const ColorFilter.mode(Colors.transparent, BlendMode.dst)
                                    : const ColorFilter.matrix(<double>[
                                        0.2126, 0.7152, 0.0722, 0, 0,
                                        0.2126, 0.7152, 0.0722, 0, 0,
                                        0.2126, 0.7152, 0.0722, 0, 0,
                                        0, 0, 0, 0.5, 0,
                                      ]),
                                child: CachedNetworkImage(
                                  imageUrl: 'https://retroachievements.org/Badge/$badgeName.png',
                                  width: 64,
                                  height: 64,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => Container(
                                    width: 64,
                                    height: 64,
                                    color: Colors.grey[800],
                                    child: const Icon(Icons.emoji_events, size: 32),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (!isEarned)
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.lock, color: Colors.white, size: 16),
                          ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Earned status badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isEarned
                          ? Colors.green.withValues(alpha: 0.2)
                          : Colors.orange.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isEarned ? Icons.check_circle : Icons.lock_outline,
                          color: isEarned ? Colors.green : Colors.orange,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isEarned ? 'UNLOCKED' : 'LOCKED',
                          style: TextStyle(
                            color: isEarned ? Colors.green : Colors.orange,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Title
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),

                  // Description
                  Text(
                    description,
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[300]
                          : Colors.grey[700],
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),

                  // Points and rarity badges row
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star, size: 12, color: Colors.amber),
                            const SizedBox(width: 3),
                            Text(
                              '$points pts',
                              style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: (rarityInfo['color'] as Color).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: (rarityInfo['color'] as Color).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(rarityInfo['icon'] as IconData, size: 12, color: rarityInfo['color'] as Color),
                            const SizedBox(width: 3),
                            Text(
                              rarityInfo['label'] as String,
                              style: TextStyle(color: rarityInfo['color'] as Color, fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      if (isMissable)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.warning_amber, size: 12, color: Colors.red),
                              SizedBox(width: 3),
                              Text('Missable', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 11)),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Enhanced rarity visualization
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (rarityInfo['color'] as Color).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: (rarityInfo['color'] as Color).withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      children: [
                        // Rarity bar
                        Row(
                          children: [
                            Text(
                              'Rarity',
                              style: TextStyle(
                                color: rarityInfo['color'] as Color,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              numDistinctPlayers > 0
                                  ? '${unlockPercent.toStringAsFixed(2)}%'
                                  : 'N/A',
                              style: TextStyle(
                                color: rarityInfo['color'] as Color,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Progress bar
                        Stack(
                          children: [
                            Container(
                              height: 8,
                              decoration: BoxDecoration(
                                color: (rarityInfo['color'] as Color).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: (unlockPercent / 100).clamp(0.0, 1.0),
                              child: Container(
                                height: 8,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      rarityInfo['color'] as Color,
                                      (rarityInfo['color'] as Color).withValues(alpha: 0.7),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (rarityInfo['color'] as Color).withValues(alpha: 0.5),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Stats row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.people, size: 12, color: Colors.cyan[600]),
                                const SizedBox(width: 4),
                                Text(
                                  '$numAwarded unlocks',
                                  style: TextStyle(
                                    color: Colors.cyan[600],
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            if (numDistinctPlayers > 0)
                              Text(
                                'of $numDistinctPlayers players',
                                style: TextStyle(
                                  color: Theme.of(ctx).brightness == Brightness.dark ? Colors.grey[400] : Colors.grey[600],
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // User info
                  if (username != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: fetchedUserPic != null && fetchedUserPic.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: 'https://retroachievements.org$fetchedUserPic',
                                    width: 32,
                                    height: 32,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => Container(
                                      width: 32,
                                      height: 32,
                                      color: Colors.grey[700],
                                      child: Center(
                                        child: Text(
                                          username![0].toUpperCase(),
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                      ),
                                    ),
                                  )
                                : Container(
                                    width: 32,
                                    height: 32,
                                    color: Colors.grey[700],
                                    child: Center(
                                      child: Text(
                                        username![0].toUpperCase(),
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                                      ),
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(username!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                Text(
                                  isEarned ? 'Unlocked ${_formatDate(dateEarned)}' : 'Not yet unlocked',
                                  style: TextStyle(
                                    color: isEarned ? Colors.green : Colors.grey,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Action buttons row
                  Row(
                    children: [
                      // Tips button with comment count
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            if (achievementId > 0) {
                              _showCommentsSheet(ctx, ref, achievementId, title);
                            }
                          },
                          icon: Icon(
                            commentCount > 0 ? Icons.lightbulb : Icons.lightbulb_outline,
                            size: 16,
                            color: commentCount > 0 ? Colors.amber : null,
                          ),
                          label: Text(commentCount > 0 ? 'Tips ($commentCount)' : 'Tips'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            side: commentCount > 0 ? const BorderSide(color: Colors.amber) : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Share button
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ShareCardScreen(
                                  type: ShareCardType.achievement,
                                  data: {
                                    'Title': title,
                                    'Description': description,
                                    'Points': points,
                                    'TrueRatio': achievement['TrueRatio'] ?? 0,
                                    'BadgeName': badgeName,
                                    'GameTitle': gameTitle ?? '',
                                    'GameIcon': gameIcon ?? '',
                                    'ConsoleName': consoleName ?? '',
                                    'Username': username ?? '',
                                    'UserPic': fetchedUserPic ?? '',
                                    'IsEarned': isEarned,
                                    'DateEarned': dateEarned,
                                    'UnlockPercent': unlockPercent,
                                    'RarityLabel': rarityInfo['label'],
                                  },
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.share, size: 16),
                          label: const Text('Share'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                    ],
                  ),
                ),
              ),
              // X button in top right
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey.withValues(alpha: 0.2),
                    padding: const EdgeInsets.all(4),
                    minimumSize: const Size(32, 32),
                  ),
                  iconSize: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    ).then((_) {
      // Update cache after dialog closes so the tile rebuilds with the badge
      if (achievementId > 0 && commentCount > 0) {
        ref.read(commentCountCacheProvider.notifier).setCount(achievementId, commentCount);
      }
    });
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inDays == 0) return 'today';
      if (diff.inDays == 1) return 'yesterday';
      if (diff.inDays < 7) return '${diff.inDays} days ago';
      if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} weeks ago';
      if (diff.inDays < 365) return '${(diff.inDays / 30).floor()} months ago';
      return '${(diff.inDays / 365).floor()} years ago';
    } catch (e) {
      return dateStr;
    }
  }

  void _showCommentsSheet(BuildContext context, WidgetRef ref, int achievementId, String title) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CommentsSheet(
        achievementId: achievementId,
        achievementTitle: title,
      ),
    );
  }
}

/// Bottom sheet for displaying achievement comments/tips
class _CommentsSheet extends ConsumerStatefulWidget {
  final int achievementId;
  final String achievementTitle;

  const _CommentsSheet({
    required this.achievementId,
    required this.achievementTitle,
  });

  @override
  ConsumerState<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends ConsumerState<_CommentsSheet> {
  List<Map<String, dynamic>>? _comments;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  Future<void> _loadComments() async {
    final api = ref.read(apiDataSourceProvider);
    final comments = await api.getAchievementComments(widget.achievementId);
    if (mounted) {
      setState(() {
        _comments = comments;
        _isLoading = false;
      });
      // Update cache with successful fetch
      if (comments != null) {
        ref.read(commentCountCacheProvider.notifier).setCount(widget.achievementId, comments.length);
      }
    }
  }

  String _formatCommentDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inDays == 0) return 'today';
      if (diff.inDays == 1) return 'yesterday';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
      if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
      return '${(diff.inDays / 365).floor()}y ago';
    } catch (e) {
      return '';
    }
  }

  Future<void> _openCommentsOnWeb() async {
    final url = Uri.parse('https://retroachievements.org/achievement/${widget.achievementId}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  /// Build text with clickable URLs
  Widget _buildLinkifiedText(String text, TextStyle baseStyle) {
    // Regex to match URLs
    final urlRegex = RegExp(
      r'https?://[^\s\)\]]+',
      caseSensitive: false,
    );

    final matches = urlRegex.allMatches(text);
    if (matches.isEmpty) {
      return Text(text, style: baseStyle);
    }

    final spans = <InlineSpan>[];
    int lastEnd = 0;

    for (final match in matches) {
      // Add text before the URL
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: baseStyle,
        ));
      }

      // Add the URL as a clickable link
      final url = match.group(0)!;
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: GestureDetector(
          onTap: () async {
            final uri = Uri.tryParse(url);
            if (uri != null && await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
          child: Text(
            url,
            style: baseStyle.copyWith(
              color: Colors.blue,
              decoration: TextDecoration.underline,
              decorationColor: Colors.blue,
            ),
          ),
        ),
      ));

      lastEnd = match.end;
    }

    // Add remaining text after the last URL
    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: baseStyle,
      ));
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (context, scrollController) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[900] : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb, color: Colors.amber, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tips & Comments',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.achievementTitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _comments == null || _comments!.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey[400]),
                                const SizedBox(height: 16),
                                Text(
                                  'No tips yet',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey[500],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Be the first to share a tip!',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[400],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: _comments!.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final comment = _comments![index];
                            final user = comment['User'] ?? 'Unknown';
                            final text = comment['CommentText'] ?? '';
                            final date = _formatCommentDate(comment['Submitted']);

                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.05)
                                    : Colors.grey.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: CachedNetworkImage(
                                          imageUrl: 'https://retroachievements.org/UserPic/$user.png',
                                          width: 24,
                                          height: 24,
                                          fit: BoxFit.cover,
                                          errorWidget: (_, __, ___) => Container(
                                            width: 24,
                                            height: 24,
                                            color: Colors.grey[700],
                                            child: Center(
                                              child: Text(
                                                user.isNotEmpty ? user[0].toUpperCase() : '?',
                                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        user,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        date,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  _buildLinkifiedText(
                                    text,
                                    TextStyle(
                                      fontSize: 13,
                                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
            // Add comment button
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _openCommentsOnWeb,
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Add Comment on RetroAchievements'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
          ),
        ),
      ),
    );
  }
}

