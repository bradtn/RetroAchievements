import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme_utils.dart';
import '../../../core/animations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/premium_provider.dart';
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

    // Fetch user profile to get avatar
    String? fetchedUserPic = userPic;
    if (fetchedUserPic == null || fetchedUserPic.isEmpty) {
      final api = ref.read(apiDataSourceProvider);
      final profile = await api.getUserProfile(username ?? '');
      fetchedUserPic = profile?['UserPic'] ?? '';
    }

    if (!context.mounted) return;

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

                  // Share button (for all achievements)
                  SizedBox(
                    width: double.infinity,
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
    );
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
}

