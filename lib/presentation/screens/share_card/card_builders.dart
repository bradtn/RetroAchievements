import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'share_card_settings.dart';
import 'share_card_widgets.dart';
import '../game_detail/game_detail_helpers.dart';
import '../../../core/utils/smart_text_wrapper.dart';

class ProfileCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final ShareCardSettings settings;

  const ProfileCard({
    super.key,
    required this.data,
    this.settings = const ShareCardSettings(),
  });

  /// Format number with commas (exact, no rounding)
  String _formatWithCommas(dynamic num) {
    final n = int.tryParse(num.toString()) ?? 0;
    final str = n.toString();
    final result = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) result.write(',');
      result.write(str[i]);
    }
    return result.toString();
  }

  @override
  Widget build(BuildContext context) {
    final username = data['Username'] ?? data['User'] ?? 'Player';
    final points = data['TotalPoints'] ?? 0;
    final truePoints = data['TotalTruePoints'] ?? 0;
    final softcorePoints = data['TotalSoftcorePoints'] ?? 0;
    final rank = data['Rank'] ?? '-';
    final userPic = data['UserPic'] ?? '';

    // Square-optimized layout with stats
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Avatar + Username + Rank
        Column(
          children: [
            _buildAvatar(username, userPic, 40),
            const SizedBox(height: 10),
            Text(username, style: getCardTextStyle(fontStyle: settings.fontStyle, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(color: Colors.purple.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(10)),
              child: Text('Rank #$rank', style: getCardTextStyle(fontStyle: settings.fontStyle, fontSize: 12, color: Colors.white.withValues(alpha: 0.9))),
            ),
          ],
        ),

        // Stats row - 3 stats in a row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStatBadge(Icons.stars, _formatWithCommas(points), 'Hardcore', Colors.amber),
            _buildStatBadge(Icons.military_tech, _formatWithCommas(truePoints), 'True Points', Colors.purple[200]!),
            _buildStatBadge(Icons.star_border, _formatWithCommas(softcorePoints), 'Softcore', Colors.blue),
          ],
        ),

        // Branding
        Branding(fontStyle: settings.fontStyle),
      ],
    );
  }

  Widget _buildAvatar(String username, String userPic, double radius) {
    final avatarSize = radius * 2;
    final content = userPic.isNotEmpty
        ? CachedNetworkImage(
            imageUrl: 'https://retroachievements.org$userPic',
            width: avatarSize,
            height: avatarSize,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => _buildAvatarPlaceholder(username, avatarSize),
          )
        : _buildAvatarPlaceholder(username, avatarSize);

    return Container(
      decoration: getAvatarDecoration(
        frame: settings.avatarFrame,
        size: avatarSize,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8)],
      ),
      child: clipAvatar(frame: settings.avatarFrame, size: avatarSize, child: content),
    );
  }

  Widget _buildAvatarPlaceholder(String username, double size) {
    return Container(
      width: size,
      height: size,
      color: Colors.grey[800],
      child: Center(child: Text(username.isNotEmpty ? username[0].toUpperCase() : '?', style: TextStyle(fontSize: size * 0.36, color: Colors.white))),
    );
  }

  Widget _buildStatBadge(IconData icon, String value, String label, Color color) {
    return SizedBox(
      width: 110,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: getCardTextStyle(fontStyle: settings.fontStyle, fontSize: 15, fontWeight: FontWeight.bold)),
          ),
          Text(label, style: getCardTextStyle(fontStyle: settings.fontStyle, fontSize: 10, color: Colors.white.withValues(alpha: 0.7))),
        ],
      ),
    );
  }
}

class GameCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String username;
  final ShareCardSettings settings;

  const GameCard({
    super.key,
    required this.data,
    required this.username,
    this.settings = const ShareCardSettings(),
  });

  @override
  Widget build(BuildContext context) {
    final title = data['Title'] ?? 'Game';
    final consoleName = data['ConsoleName'] ?? '';
    final imageIcon = data['ImageIcon'] ?? '';
    final earned = data['NumAwardedToUser'] ?? data['NumAchieved'] ?? 0;
    final total = data['NumAchievements'] ?? data['NumPossibleAchievements'] ?? 0;
    final points = data['Points'] ?? data['PossibleScore'] ?? 0;
    final earnedPoints = data['ScoreAchieved'] ?? 0;
    final progress = total > 0 ? earned / total : 0.0;
    final isMastered = earned == total && total > 0;

    // Square-optimized layout
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Game icon
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 2),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8)],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: 'https://retroachievements.org$imageIcon',
              width: 70,
              height: 70,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Container(width: 70, height: 70, color: Colors.grey[800], child: const Icon(Icons.games, size: 36, color: Colors.white)),
            ),
          ),
        ),

        // Title + Console
        Column(
          children: [
            Text(
              title,
              style: getCardTextStyle(fontStyle: settings.fontStyle, fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (consoleName.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                child: Text(consoleName, style: getCardTextStyle(fontStyle: settings.fontStyle, fontSize: 10, fontWeight: FontWeight.w600, color: Colors.blue)),
              ),
          ],
        ),

        // Progress section
        Column(
          children: [
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 12,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation(isMastered ? Colors.amber : Colors.green),
              ),
            ),
            const SizedBox(height: 6),
            // Stats row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.emoji_events, color: Colors.green, size: 14),
                const SizedBox(width: 4),
                Text('$earned/$total', style: getCardTextStyle(fontStyle: settings.fontStyle, fontSize: 11)),
                const SizedBox(width: 12),
                Icon(Icons.stars, color: Colors.amber[300], size: 14),
                const SizedBox(width: 4),
                Text('$earnedPoints/$points', style: getCardTextStyle(fontStyle: settings.fontStyle, fontSize: 11, color: Colors.amber[300]!)),
              ],
            ),
          ],
        ),

        // Player info
        PlayerTag(username: username, frame: settings.avatarFrame, fontStyle: settings.fontStyle),

        // Branding
        Branding(fontStyle: settings.fontStyle),
      ],
    );
  }
}

/// Epic share card for mastered games (100% completion)
/// Special gold-trimmed card that users get automatically for mastery
class MasteredGameCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String username;
  final ShareCardSettings settings;

  const MasteredGameCard({
    super.key,
    required this.data,
    required this.username,
    this.settings = const ShareCardSettings(),
  });

  @override
  Widget build(BuildContext context) {
    final title = data['Title'] ?? 'Game';
    final consoleName = data['ConsoleName'] ?? '';
    final imageIcon = data['ImageIcon'] ?? '';
    final earned = data['NumAwardedToUser'] ?? data['NumAchieved'] ?? 0;
    final total = data['NumAchievements'] ?? data['NumPossibleAchievements'] ?? 0;
    final totalPoints = data['Points'] ?? data['PossibleScore'] ?? 0;
    final earnedPoints = data['ScoreAchieved'] ?? totalPoints;
    final achievements = data['Achievements'] as Map<String, dynamic>? ?? {};

    // Calculate mastery time
    final masteryInfo = calculateMasteryTime(achievements, earned, total);
    final masteryDuration = masteryInfo?.formattedDuration ?? 'Unknown';

    // Ultra premium gold trim - inner area is transparent to show card background
    return Container(
      padding: const EdgeInsets.all(4), // Gold border
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.amber.shade200,
            Colors.orange.shade600,
            Colors.yellow.shade400,
            Colors.amber.shade500,
            Colors.orange.shade700,
            Colors.amber.shade300,
          ],
          stops: const [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
        ),
        boxShadow: [
          BoxShadow(color: Colors.amber.withValues(alpha: 0.5), blurRadius: 12, spreadRadius: 1),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          // Semi-transparent dark overlay to keep text readable while showing background
          color: Colors.black.withValues(alpha: 0.6),
          // Inner gold accent border
          border: Border.all(
            color: Colors.amber.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top: Player tag (who mastered it)
            PlayerTag(username: username, frame: settings.avatarFrame, fontStyle: settings.fontStyle),

            // Game icon with trophy badge and glow - compact
            Stack(
              alignment: Alignment.center,
              children: [
                // Outer gold glow ring
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.amber.withValues(alpha: 0.4),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                // Game icon with gold border
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.amber.shade200, Colors.orange.shade600, Colors.amber.shade400],
                    ),
                    boxShadow: [
                      BoxShadow(color: Colors.amber.withValues(alpha: 0.5), blurRadius: 10),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: CachedNetworkImage(
                      imageUrl: 'https://retroachievements.org$imageIcon',
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(width: 56, height: 56, color: Colors.grey[800], child: const Icon(Icons.games, size: 28, color: Colors.amber)),
                    ),
                  ),
                ),
                // Trophy badge
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [Colors.amber.shade300, Colors.orange.shade700]),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                      boxShadow: [BoxShadow(color: Colors.amber.withValues(alpha: 0.6), blurRadius: 6)],
                    ),
                    child: const Icon(Icons.workspace_premium, color: Colors.white, size: 12),
                  ),
                ),
              ],
            ),

            // MASTERED banner + Title + Console - Compact
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // MASTERED banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.amber.shade400, Colors.orange.shade600, Colors.amber.shade500],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade200, width: 1),
                    boxShadow: [BoxShadow(color: Colors.amber.withValues(alpha: 0.4), blurRadius: 8)],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.emoji_events, color: Colors.white, size: 14),
                      const SizedBox(width: 5),
                      Text('MASTERED', style: getCardTextStyle(fontStyle: settings.fontStyle, fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
                      const SizedBox(width: 5),
                      const Icon(Icons.emoji_events, color: Colors.white, size: 14),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                // Title with gold shimmer
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [Colors.white, Colors.amber.shade200, Colors.white],
                  ).createShader(bounds),
                  child: Text(
                    title,
                    style: getCardTextStyle(fontStyle: settings.fontStyle, fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (consoleName.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(consoleName, style: getCardTextStyle(fontStyle: settings.fontStyle, fontSize: 9, color: Colors.amber.shade300)),
                  ),
              ],
            ),

            // Stats row: achievements + points + time - Compact
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Achievements
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.emoji_events, color: Colors.amber.shade400, size: 12),
                          const SizedBox(width: 4),
                          Text('$earned/$total', style: getCardTextStyle(fontStyle: settings.fontStyle, fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber.shade300)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Points
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.stars, color: Colors.amber.shade400, size: 12),
                          const SizedBox(width: 4),
                          Text('$earnedPoints/$totalPoints', style: getCardTextStyle(fontStyle: settings.fontStyle, fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber.shade300)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Completion time
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.timer_outlined, color: Colors.amber.shade300, size: 14),
                      const SizedBox(width: 6),
                      Text(masteryDuration, style: getCardTextStyle(fontStyle: settings.fontStyle, fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber.shade300)),
                    ],
                  ),
                ),
              ],
            ),

            // Bottom: Branding centered
            Branding(fontStyle: settings.fontStyle, logoSize: 50),
          ],
        ),
      ),
    );
  }
}

class AchievementCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final ShareCardSettings settings;

  const AchievementCard({
    super.key,
    required this.data,
    this.settings = const ShareCardSettings(),
  });

  @override
  Widget build(BuildContext context) {
    final title = data['Title'] ?? 'Achievement';
    final description = data['Description'] ?? '';
    final points = data['Points'] ?? 0;
    final badgeName = data['BadgeName'] ?? '';
    final gameTitle = data['GameTitle'] ?? '';
    final gameIcon = data['GameIcon'] ?? '';
    final consoleName = data['ConsoleName'] ?? data['consoleName'] ?? '';
    final username = data['Username'] ?? '';
    final userPic = data['UserPic'] ?? '';
    final isEarned = data['IsEarned'] == true;
    final unlockPercent = data['UnlockPercent'];
    final isHardcore = data['HardcoreMode'] == 1;

    // Square card optimized layout
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Top: Game info row
        if (gameTitle.isNotEmpty || gameIcon.isNotEmpty)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (gameIcon.isNotEmpty)
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: CachedNetworkImage(
                      imageUrl: 'https://retroachievements.org$gameIcon',
                      width: 24,
                      height: 24,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        width: 24,
                        height: 24,
                        color: Colors.grey[700],
                        child: const Icon(Icons.games, size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              if (gameIcon.isNotEmpty && gameTitle.isNotEmpty)
                const SizedBox(width: 8),
              if (gameTitle.isNotEmpty)
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        gameTitle,
                        style: getCardTextStyle(
                          fontStyle: settings.fontStyle,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (consoleName.isNotEmpty)
                        Text(
                          consoleName,
                          style: getCardTextStyle(
                            fontStyle: settings.fontStyle,
                            fontSize: 9,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                          textAlign: TextAlign.center,
                        ),
                    ],
                  ),
                ),
            ],
          )
        else
          const SizedBox.shrink(),

        // Badge with lock overlay - scaled down
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isEarned ? Colors.amber : Colors.grey[600]!,
                  width: 3,
                ),
                boxShadow: [
                  if (isEarned)
                    BoxShadow(
                      color: Colors.amber.withValues(alpha: 0.4),
                      blurRadius: 15,
                      spreadRadius: 1,
                    ),
                ],
              ),
              child: ClipOval(
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
                    width: 70,
                    height: 70,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      width: 70,
                      height: 70,
                      color: Colors.grey[800],
                      child: const Icon(Icons.emoji_events, size: 32, color: Colors.amber),
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

        // Status + Title + Description
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Earned/Hardcore badges row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isEarned
                        ? Colors.green.withValues(alpha: 0.3)
                        : Colors.red.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isEarned
                          ? Colors.green.withValues(alpha: 0.5)
                          : Colors.red.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isEarned ? Icons.check_circle : Icons.lock_outline,
                        color: isEarned ? Colors.green : Colors.red[300],
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isEarned ? 'UNLOCKED' : 'LOCKED',
                        style: getCardTextStyle(
                          fontStyle: settings.fontStyle,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isEarned ? Colors.green : Colors.red[300]!,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isHardcore) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'HC',
                      style: getCardTextStyle(
                        fontStyle: settings.fontStyle,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            // Title
            Text(
              title,
              style: getCardTextStyle(
                fontStyle: settings.fontStyle,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            // Description
            Text(
              description,
              style: getCardTextStyle(
                fontStyle: settings.fontStyle,
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.8),
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),

        // User tag + Points/rarity
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (username.isNotEmpty) ...[
              PlayerTag(username: username, frame: settings.avatarFrame, fontStyle: settings.fontStyle),
              const SizedBox(height: 8),
            ],
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.stars, color: Colors.amber, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '$points pts',
                        style: getCardTextStyle(
                          fontStyle: settings.fontStyle,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber,
                        ),
                      ),
                    ],
                  ),
                ),
                if (unlockPercent != null && unlockPercent > 0)
                  _buildRarityBadge(unlockPercent),
              ],
            ),
          ],
        ),

        // Bottom: Branding centered
        Branding(fontStyle: settings.fontStyle),
      ],
    );
  }

  Widget _buildUserPlaceholder(String username) {
    return Container(
      width: 28,
      height: 28,
      color: Colors.grey[700],
      child: Center(
        child: Text(
          username.isNotEmpty ? username[0].toUpperCase() : '?',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildRarityBadge(double unlockPercent) {
    final IconData rarityIcon;
    final Color rarityColor;

    if (unlockPercent < 5) {
      rarityIcon = Icons.diamond;
      rarityColor = Colors.red;
    } else if (unlockPercent < 15) {
      rarityIcon = Icons.star;
      rarityColor = Colors.purple;
    } else if (unlockPercent < 40) {
      rarityIcon = Icons.hexagon;
      rarityColor = Colors.blue;
    } else {
      rarityIcon = Icons.circle;
      rarityColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: rarityColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: rarityColor.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(rarityIcon, color: rarityColor, size: 14),
          const SizedBox(width: 4),
          Text(
            '${unlockPercent.toStringAsFixed(1)}%',
            style: getCardTextStyle(
              fontStyle: settings.fontStyle,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: rarityColor,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.people, color: rarityColor.withValues(alpha: 0.7), size: 14),
        ],
      ),
    );
  }
}

class ComparisonCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final ShareCardSettings settings;

  const ComparisonCard({
    super.key,
    required this.data,
    this.settings = const ShareCardSettings(),
  });

  @override
  Widget build(BuildContext context) {
    final myProfile = data['myProfile'] as Map<String, dynamic>? ?? {};
    final otherProfile = data['otherProfile'] as Map<String, dynamic>? ?? {};

    final myName = myProfile['User'] ?? 'You';
    final otherName = otherProfile['User'] ?? 'Opponent';
    final myPic = myProfile['UserPic'] ?? '';
    final otherPic = otherProfile['UserPic'] ?? '';
    final myPoints = myProfile['TotalPoints'] ?? 0;
    final otherPoints = otherProfile['TotalPoints'] ?? 0;
    final myTruePoints = myProfile['TotalTruePoints'] ?? 0;
    final otherTruePoints = otherProfile['TotalTruePoints'] ?? 0;

    final myPtsNum = int.tryParse(myPoints.toString()) ?? 0;
    final otherPtsNum = int.tryParse(otherPoints.toString()) ?? 0;
    final winner = myPtsNum > otherPtsNum ? 'me' : (otherPtsNum > myPtsNum ? 'other' : 'tie');
    final isCompact = settings.layout == CardLayout.compact;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // VS Header
        Row(
          children: [
            Expanded(
              child: _buildPlayerColumn(
                name: myName,
                pic: myPic,
                isWinner: winner == 'me',
                isCompact: isCompact,
              ),
            ),
            Container(
              padding: EdgeInsets.all(isCompact ? 8 : 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Text(
                'VS',
                style: getCardTextStyle(
                  fontStyle: settings.fontStyle,
                  fontSize: isCompact ? 12 : 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: _buildPlayerColumn(
                name: otherName,
                pic: otherPic,
                isWinner: winner == 'other',
                isCompact: isCompact,
                isOpponent: true,
              ),
            ),
          ],
        ),
        SizedBox(height: isCompact ? 16 : 24),

        // Stats comparison
        _buildComparisonRow(
          label: 'Points',
          myValue: formatNumber(myPoints),
          otherValue: formatNumber(otherPoints),
          myWins: myPtsNum > otherPtsNum,
          otherWins: otherPtsNum > myPtsNum,
          isCompact: isCompact,
        ),
        if (!isCompact) ...[
          const SizedBox(height: 8),
          _buildComparisonRow(
            label: 'True Points',
            myValue: formatNumber(myTruePoints),
            otherValue: formatNumber(otherTruePoints),
            myWins: (int.tryParse(myTruePoints.toString()) ?? 0) > (int.tryParse(otherTruePoints.toString()) ?? 0),
            otherWins: (int.tryParse(otherTruePoints.toString()) ?? 0) > (int.tryParse(myTruePoints.toString()) ?? 0),
            isCompact: isCompact,
          ),
        ],
        SizedBox(height: isCompact ? 16 : 24),

        Branding(fontStyle: settings.fontStyle),
      ],
    );
  }

  Widget _buildPlayerColumn({
    required String name,
    required String pic,
    required bool isWinner,
    required bool isCompact,
    bool isOpponent = false,
  }) {
    final avatarSize = isCompact ? 28.0 : 35.0;
    return Column(
      children: [
        Container(
          decoration: getAvatarDecoration(
            frame: settings.avatarFrame,
            size: avatarSize * 2,
            borderColor: isWinner
                ? (isOpponent ? Colors.red : Colors.green)
                : Colors.white.withValues(alpha: 0.5),
            borderWidth: isWinner ? 3 : 2,
          ),
          child: clipAvatar(
            frame: settings.avatarFrame,
            size: avatarSize * 2,
            child: pic.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: 'https://retroachievements.org$pic',
                    width: avatarSize * 2,
                    height: avatarSize * 2,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      width: avatarSize * 2,
                      height: avatarSize * 2,
                      color: Colors.grey[800],
                    ),
                  )
                : Container(
                    width: avatarSize * 2,
                    height: avatarSize * 2,
                    color: Colors.grey[800],
                  ),
          ),
        ),
        SizedBox(height: isCompact ? 6 : 8),
        Text(
          name,
          style: getCardTextStyle(
            fontStyle: settings.fontStyle,
            fontSize: isCompact ? 12 : 14,
            fontWeight: FontWeight.bold,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        if (isWinner)
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isOpponent ? Colors.red : Colors.green,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'WINNER',
              style: getCardTextStyle(
                fontStyle: settings.fontStyle,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildComparisonRow({
    required String label,
    required String myValue,
    required String otherValue,
    required bool myWins,
    required bool otherWins,
    required bool isCompact,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 12 : 16,
        vertical: isCompact ? 8 : 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              myValue,
              style: getCardTextStyle(
                fontStyle: settings.fontStyle,
                fontSize: isCompact ? 14 : 18,
                fontWeight: FontWeight.bold,
                color: myWins ? Colors.green : Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Text(
            label,
            style: getCardTextStyle(
              fontStyle: settings.fontStyle,
              fontSize: isCompact ? 10 : 12,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          Expanded(
            child: Text(
              otherValue,
              style: getCardTextStyle(
                fontStyle: settings.fontStyle,
                fontSize: isCompact ? 14 : 18,
                fontWeight: FontWeight.bold,
                color: otherWins ? Colors.red : Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class MilestoneCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final ShareCardSettings settings;

  const MilestoneCard({
    super.key,
    required this.data,
    this.settings = const ShareCardSettings(),
  });

  @override
  Widget build(BuildContext context) {
    final title = data['title'] ?? 'Milestone';
    final description = data['description'] ?? '';
    final category = data['category'] ?? '';
    final username = data['username'] ?? 'Player';
    final userPic = data['userPic'] ?? '';
    final iconCode = data['iconCode'] as int? ?? Icons.emoji_events.codePoint;
    final colorValue = data['colorValue'] as int? ?? Colors.amber.toARGB32();
    final milestoneColor = Color(colorValue);
    final isEarned = data['isEarned'] == true;
    final currentValue = data['currentValue'] as int? ?? 0;
    final requirement = data['requirement'] as int? ?? 1;
    final progress = requirement > 0 ? (currentValue / requirement).clamp(0.0, 1.0) : 0.0;
    final isCompact = settings.layout == CardLayout.compact;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Milestone badge - flexible to shrink if needed
        Flexible(
          flex: 3,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Container(
              width: isCompact ? 70 : 85,
              height: isCompact ? 70 : 85,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: milestoneColor.withValues(alpha: isEarned ? 0.2 : 0.15),
                border: Border.all(
                  color: milestoneColor.withValues(alpha: isEarned ? 1.0 : 0.5),
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: milestoneColor.withValues(alpha: isEarned ? 0.4 : 0.2),
                    blurRadius: isEarned ? 15 : 8,
                  ),
                ],
              ),
              child: Icon(
                IconData(iconCode, fontFamily: 'MaterialIcons'),
                size: isCompact ? 32 : 40,
                color: milestoneColor.withValues(alpha: isEarned ? 1.0 : 0.7),
              ),
            ),
          ),
        ),
        SizedBox(height: isCompact ? 8 : 10),

        // Category chip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: milestoneColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            category,
            style: getCardTextStyle(
              fontStyle: settings.fontStyle,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: milestoneColor,
            ),
          ),
        ),
        SizedBox(height: isCompact ? 6 : 8),

        // Title - flexible with max lines
        Flexible(
          flex: 2,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                title,
                style: getCardTextStyle(
                  fontStyle: settings.fontStyle,
                  fontSize: isCompact ? 16 : 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
        if (!isCompact && description.isNotEmpty) ...[
          const SizedBox(height: 4),
          // Description - constrained
          Flexible(
            flex: 1,
            child: Text(
              description,
              style: getCardTextStyle(
                fontStyle: settings.fontStyle,
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.8),
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
        SizedBox(height: isCompact ? 10 : 12),

        // Earned badge or progress
        if (isEarned)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.green.withValues(alpha: 0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 16),
                const SizedBox(width: 4),
                Text(
                  'EARNED',
                  style: getCardTextStyle(
                    fontStyle: settings.fontStyle,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          )
        else
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$currentValue / $requirement',
                style: getCardTextStyle(
                  fontStyle: settings.fontStyle,
                  fontSize: isCompact ? 12 : 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: 160,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress,
                  child: Container(
                    decoration: BoxDecoration(
                      color: milestoneColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${(progress * 100).toInt()}% complete',
                style: getCardTextStyle(
                  fontStyle: settings.fontStyle,
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        SizedBox(height: isCompact ? 10 : 12),

        // User info
        _buildUserInfo(username, userPic),
        SizedBox(height: isCompact ? 10 : 12),

        Branding(fontStyle: settings.fontStyle),
      ],
    );
  }

  Widget _buildUserInfo(String username, String userPic) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: getAvatarDecoration(
              frame: settings.avatarFrame,
              size: 28,
              borderWidth: 0,
            ),
            child: clipAvatar(
              frame: settings.avatarFrame,
              size: 28,
              child: userPic.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: 'https://retroachievements.org$userPic',
                      width: 28,
                      height: 28,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        width: 28,
                        height: 28,
                        color: Colors.grey[700],
                        child: Center(
                          child: Text(
                            username.isNotEmpty ? username[0].toUpperCase() : '?',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    )
                  : Container(
                      width: 28,
                      height: 28,
                      color: Colors.grey[700],
                      child: Center(
                        child: Text(
                          username.isNotEmpty ? username[0].toUpperCase() : '?',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            username,
            style: getCardTextStyle(
              fontStyle: settings.fontStyle,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class RAAwardCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final ShareCardSettings settings;

  const RAAwardCard({
    super.key,
    required this.data,
    this.settings = const ShareCardSettings(),
  });

  @override
  Widget build(BuildContext context) {
    final title = data['title'] ?? 'Award';
    final consoleName = data['consoleName'] ?? '';
    final awardType = data['awardType'] ?? 'Award';
    final imageIcon = data['imageIcon'] ?? '';
    final awardedAt = data['awardedAt'] ?? '';
    final username = data['username'] ?? 'Player';
    final userPic = data['userPic'] ?? '';
    final colorValue = data['colorValue'] as int? ?? Colors.amber.toARGB32();
    final awardColor = Color(colorValue);
    final isCompact = settings.layout == CardLayout.compact;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Game/Award icon - flexible to shrink
        Flexible(
          flex: 3,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: awardColor, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: awardColor.withValues(alpha: 0.4),
                    blurRadius: 15,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: CachedNetworkImage(
                  imageUrl: 'https://retroachievements.org$imageIcon',
                  width: isCompact ? 75 : 90,
                  height: isCompact ? 75 : 90,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(
                    width: isCompact ? 75 : 90,
                    height: isCompact ? 75 : 90,
                    color: Colors.grey[800],
                    child: Icon(Icons.emoji_events, size: isCompact ? 36 : 44, color: awardColor),
                  ),
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: isCompact ? 8 : 10),

        // Award type badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: awardColor.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: awardColor.withValues(alpha: 0.6)),
          ),
          child: Text(
            awardType.toUpperCase(),
            style: getCardTextStyle(
              fontStyle: settings.fontStyle,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: awardColor,
            ),
          ),
        ),
        SizedBox(height: isCompact ? 6 : 8),

        // Title - flexible with max lines
        Flexible(
          flex: 2,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                title,
                style: getCardTextStyle(
                  fontStyle: settings.fontStyle,
                  fontSize: isCompact ? 16 : 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
        if (!isCompact && consoleName.isNotEmpty) ...[
          const SizedBox(height: 4),
          // Console
          Text(
            consoleName,
            style: getCardTextStyle(
              fontStyle: settings.fontStyle,
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.7),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        if (!isCompact && awardedAt.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            'Awarded: ${_formatAwardDate(awardedAt)}',
            style: getCardTextStyle(
              fontStyle: settings.fontStyle,
              fontSize: 10,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ],
        SizedBox(height: isCompact ? 10 : 12),

        // User info
        _buildUserInfo(username, userPic),
        SizedBox(height: isCompact ? 10 : 12),

        Branding(fontStyle: settings.fontStyle),
      ],
    );
  }

  Widget _buildUserInfo(String username, String userPic) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: getAvatarDecoration(
              frame: settings.avatarFrame,
              size: 28,
              borderWidth: 0,
            ),
            child: clipAvatar(
              frame: settings.avatarFrame,
              size: 28,
              child: userPic.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: 'https://retroachievements.org$userPic',
                      width: 28,
                      height: 28,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        width: 28,
                        height: 28,
                        color: Colors.grey[700],
                        child: Center(
                          child: Text(
                            username.isNotEmpty ? username[0].toUpperCase() : '?',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    )
                  : Container(
                      width: 28,
                      height: 28,
                      color: Colors.grey[700],
                      child: Center(
                        child: Text(
                          username.isNotEmpty ? username[0].toUpperCase() : '?',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            username,
            style: getCardTextStyle(
              fontStyle: settings.fontStyle,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatAwardDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.month}/${date.day}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }
}

class StreakCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final ShareCardSettings settings;

  const StreakCard({
    super.key,
    required this.data,
    this.settings = const ShareCardSettings(),
  });

  @override
  Widget build(BuildContext context) {
    final currentStreak = data['currentStreak'] as int? ?? 0;
    final bestStreak = data['bestStreak'] as int? ?? 0;
    final username = data['username'] as String? ?? 'Player';
    final isActive = data['isActive'] as bool? ?? false;
    final isCompact = settings.layout == CardLayout.compact;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Fire icon
        Container(
          width: isCompact ? 80 : 100,
          height: isCompact ? 80 : 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.orange.shade400,
                Colors.deepOrange.shade600,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withValues(alpha: 0.5),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(
            Icons.local_fire_department,
            size: isCompact ? 42 : 56,
            color: Colors.white,
          ),
        ),
        SizedBox(height: isCompact ? 14 : 20),

        // Current streak
        Text(
          '$currentStreak',
          style: getCardTextStyle(
            fontStyle: settings.fontStyle,
            fontSize: isCompact ? 48 : 64,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          'DAY STREAK',
          style: getCardTextStyle(
            fontStyle: settings.fontStyle,
            fontSize: isCompact ? 14 : 18,
            fontWeight: FontWeight.bold,
            color: Colors.orange.shade300,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),

        // Status
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: isActive ? Colors.green.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            isActive ? 'ON FIRE!' : 'STREAK ENDED',
            style: getCardTextStyle(
              fontStyle: settings.fontStyle,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isActive ? Colors.green.shade300 : Colors.grey.shade400,
            ),
          ),
        ),
        SizedBox(height: isCompact ? 14 : 20),

        // Best streak
        if (!isCompact)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.emoji_events, color: Colors.amber.shade300, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Best: $bestStreak days',
                  style: getCardTextStyle(
                    fontStyle: settings.fontStyle,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.amber.shade300,
                  ),
                ),
              ],
            ),
          ),
        if (!isCompact) const SizedBox(height: 20),

        // Username
        Text(
          username,
          style: getCardTextStyle(
            fontStyle: settings.fontStyle,
            fontSize: isCompact ? 14 : 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: isCompact ? 14 : 20),

        Branding(fontStyle: settings.fontStyle),
      ],
    );
  }
}

class AwardsSummaryCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final ShareCardSettings settings;

  const AwardsSummaryCard({
    super.key,
    required this.data,
    this.settings = const ShareCardSettings(),
  });

  @override
  Widget build(BuildContext context) {
    final username = data['username'] ?? 'Player';
    final userPic = data['userPic'] ?? '';
    final totalAwards = data['totalAwards'] ?? 0;
    final masteryCount = data['masteryCount'] ?? 0;
    final beatenHardcore = data['beatenHardcore'] ?? 0;
    final beatenSoftcore = data['beatenSoftcore'] ?? 0;
    final eventAwards = data['eventAwards'] ?? 0;
    final isCompact = settings.layout == CardLayout.compact;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Avatar
        _buildAvatar(username, userPic, isCompact ? 35 : 45, settings.avatarFrame),
        SizedBox(height: isCompact ? 10 : 14),

        // Username
        Text(
          username,
          style: getCardTextStyle(
            fontStyle: settings.fontStyle,
            fontSize: isCompact ? 18 : 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: isCompact ? 12 : 16),

        // Total awards with icon
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.military_tech, color: Colors.amber, size: isCompact ? 28 : 36),
            const SizedBox(width: 8),
            Text(
              '$totalAwards',
              style: getCardTextStyle(
                fontStyle: settings.fontStyle,
                fontSize: isCompact ? 36 : 48,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        SizedBox(height: isCompact ? 4 : 8),
        Text(
          'RetroAchievements Awards',
          style: getCardTextStyle(
            fontStyle: settings.fontStyle,
            fontSize: isCompact ? 12 : 14,
            color: Colors.white70,
          ),
        ),
        SizedBox(height: isCompact ? 14 : 20),

        // Stats row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStatColumn(Icons.workspace_premium, masteryCount, 'Mastery', Colors.amber, isCompact),
            _buildStatColumn(Icons.verified, beatenHardcore, 'Beaten HC', Colors.orange, isCompact),
            _buildStatColumn(Icons.check_circle, beatenSoftcore, 'Beaten', Colors.green, isCompact),
            if (eventAwards > 0)
              _buildStatColumn(Icons.celebration, eventAwards, 'Events', Colors.purple, isCompact),
          ],
        ),
        SizedBox(height: isCompact ? 14 : 20),

        Branding(fontStyle: settings.fontStyle),
      ],
    );
  }

  Widget _buildAvatar(String username, String userPic, double size, AvatarFrame frame) {
    final imageUrl = userPic.startsWith('http')
        ? userPic
        : 'https://retroachievements.org${userPic.isNotEmpty ? userPic : '/UserPic/$username.png'}';
    return Container(
      decoration: getAvatarDecoration(
        frame: frame,
        size: size,
        borderColor: Colors.white24,
        borderWidth: 2,
      ),
      child: clipAvatar(
        frame: frame,
        size: size,
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => Container(
            width: size,
            height: size,
            color: Colors.grey[800],
            child: Icon(Icons.person, size: size / 2, color: Colors.grey),
          ),
        ),
      ),
    );
  }

  Widget _buildStatColumn(IconData icon, int value, String label, Color color, bool isCompact) {
    return Column(
      children: [
        Icon(icon, color: color, size: isCompact ? 18 : 22),
        const SizedBox(height: 4),
        Text(
          '$value',
          style: getCardTextStyle(
            fontStyle: settings.fontStyle,
            fontSize: isCompact ? 16 : 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: getCardTextStyle(
            fontStyle: settings.fontStyle,
            fontSize: isCompact ? 10 : 12,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }
}

class GoalsSummaryCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final ShareCardSettings settings;

  const GoalsSummaryCard({
    super.key,
    required this.data,
    this.settings = const ShareCardSettings(),
  });

  @override
  Widget build(BuildContext context) {
    final username = data['username'] ?? 'Player';
    final userPic = data['userPic'] ?? '';
    final completed = data['completed'] ?? 0;
    final total = data['total'] ?? 0;
    final progress = total > 0 ? completed / total : 0.0;
    final isCompact = settings.layout == CardLayout.compact;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Avatar
        _buildAvatar(username, userPic, isCompact ? 35 : 45, settings.avatarFrame),
        SizedBox(height: isCompact ? 10 : 14),

        // Username
        Text(
          username,
          style: getCardTextStyle(
            fontStyle: settings.fontStyle,
            fontSize: isCompact ? 18 : 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: isCompact ? 12 : 16),

        // Progress with icon
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.flag, color: Colors.tealAccent, size: isCompact ? 28 : 36),
            const SizedBox(width: 8),
            Text(
              '$completed / $total',
              style: getCardTextStyle(
                fontStyle: settings.fontStyle,
                fontSize: isCompact ? 36 : 48,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        SizedBox(height: isCompact ? 4 : 8),
        Text(
          'RetroTrack Goals',
          style: getCardTextStyle(
            fontStyle: settings.fontStyle,
            fontSize: isCompact ? 12 : 14,
            color: Colors.white70,
          ),
        ),
        SizedBox(height: isCompact ? 14 : 20),

        // Progress bar
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isCompact ? 20 : 30),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: isCompact ? 10 : 14,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation(Colors.tealAccent),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${(progress * 100).toStringAsFixed(1)}% Complete',
                style: getCardTextStyle(
                  fontStyle: settings.fontStyle,
                  fontSize: isCompact ? 12 : 14,
                  color: Colors.tealAccent,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: isCompact ? 14 : 20),

        Branding(fontStyle: settings.fontStyle),
      ],
    );
  }

  Widget _buildAvatar(String username, String userPic, double size, AvatarFrame frame) {
    final imageUrl = userPic.startsWith('http')
        ? userPic
        : 'https://retroachievements.org${userPic.isNotEmpty ? userPic : '/UserPic/$username.png'}';
    return Container(
      decoration: getAvatarDecoration(
        frame: frame,
        size: size,
        borderColor: Colors.white24,
        borderWidth: 2,
      ),
      child: clipAvatar(
        frame: frame,
        size: size,
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => Container(
            width: size,
            height: size,
            color: Colors.grey[800],
            child: Icon(Icons.person, size: size / 2, color: Colors.grey),
          ),
        ),
      ),
    );
  }
}

class LeaderboardCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final ShareCardSettings settings;

  const LeaderboardCard({
    super.key,
    required this.data,
    this.settings = const ShareCardSettings(),
  });

  @override
  Widget build(BuildContext context) {
    final username = data['username'] ?? 'Player';
    final userPic = data['userPic'] ?? '';
    final gameTitle = data['gameTitle'] ?? 'Unknown Game';
    final gameIcon = data['gameIcon'] ?? '';
    final rawTitle = data['leaderboardTitle'] ?? '';
    final rawDescription = data['leaderboardDescription'] ?? '';
    final rank = data['rank'] ?? 0;
    final formattedScore = data['formattedScore'] ?? '';

    // Handle empty title - use description as main title if title is empty
    final hasTitle = rawTitle.isNotEmpty;
    final hasDescription = rawDescription.isNotEmpty;
    final leaderboardTitle = hasTitle ? rawTitle : (hasDescription ? rawDescription : 'Leaderboard');
    final leaderboardDescription = hasTitle && hasDescription ? rawDescription : null;
    // Track if the "title" is actually a description (so we apply dash break logic to it)
    final titleIsActuallyDescription = !hasTitle && hasDescription;

    // Rank medal colors
    Color rankColor = Colors.blue;
    if (rank == 1) {
      rankColor = Colors.amber;
    } else if (rank == 2) {
      rankColor = Colors.grey[400]!;
    } else if (rank == 3) {
      rankColor = Colors.orange[700]!;
    } else if (rank <= 10) {
      rankColor = Colors.green;
    }

    // Square-optimized layout - all components scaled down to fit 380x380
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Top section: Game info
        Column(
          children: [
            // Game icon and title
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: CachedNetworkImage(
                    imageUrl: 'https://retroachievements.org$gameIcon',
                    width: 32,
                    height: 32,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      width: 32,
                      height: 32,
                      color: Colors.grey[800],
                      child: const Icon(Icons.videogame_asset, size: 18, color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    gameTitle,
                    style: getCardTextStyle(
                      fontStyle: settings.fontStyle,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Leaderboard title badge - layout-aware smart wrapping
            LayoutBuilder(
              builder: (context, constraints) {
                // Calculate available width for text (container width minus padding)
                final availableWidth = constraints.maxWidth - 24; // 12px padding on each side

                final titleStyle = getCardTextStyle(
                  fontStyle: settings.fontStyle,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                );

                final descStyle = getCardTextStyle(
                  fontStyle: settings.fontStyle,
                  fontSize: 10,
                  color: Colors.white70,
                );

                // Smart wrap with measurement
                // For title: use scoring-based wrapping (let it fit naturally)
                // BUT if the "title" is actually a description (no real title exists),
                // apply dash break logic for cleaner display
                final wrappedTitle = SmartTextWrapper.smartWrapMeasured(
                  text: leaderboardTitle,
                  style: titleStyle,
                  maxWidth: availableWidth,
                  maxLines: 3,
                  preferDashBreak: titleIsActuallyDescription,
                  stripDashAfterBreak: titleIsActuallyDescription,
                );

                // For description: prefer breaking at dash (everything after dash on new line)
                // Also strip the dash for cleaner display
                final wrappedDescription = leaderboardDescription != null
                    ? SmartTextWrapper.smartWrapMeasured(
                        text: leaderboardDescription,
                        style: descStyle,
                        maxWidth: availableWidth,
                        maxLines: 3, // Allow 3 lines for longer descriptions
                        preferDashBreak: true, // Always break at dash first
                        stripDashAfterBreak: true, // Remove dash for cleaner look
                      )
                    : null;

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.leaderboard, color: Colors.amber, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            'LEADERBOARD',
                            style: getCardTextStyle(
                              fontStyle: settings.fontStyle,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        wrappedTitle,
                        style: titleStyle,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                      if (wrappedDescription != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          wrappedDescription,
                          style: descStyle,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ],
        ),

        // Middle section: User + Rank
        Column(
          children: [
            // User avatar
            _buildAvatar(username, userPic, 36, settings.avatarFrame),
            const SizedBox(height: 6),

            // Username
            Text(
              username,
              style: getCardTextStyle(
                fontStyle: settings.fontStyle,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),

            // Rank display - scaled down
            if (rank <= 3) ...[
              _buildTrophyRank(rank, rankColor, formattedScore, true),
            ] else ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: rankColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: rankColor.withValues(alpha: 0.5), width: 2),
                ),
                child: Text(
                  '#$rank',
                  style: getCardTextStyle(
                    fontStyle: settings.fontStyle,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: rankColor,
                  ),
                ),
              ),
              if (formattedScore.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  formattedScore,
                  style: getCardTextStyle(
                    fontStyle: settings.fontStyle,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.tealAccent,
                  ),
                ),
              ],
            ],
          ],
        ),

        // Bottom section: Branding
        Branding(fontStyle: settings.fontStyle),
      ],
    );
  }

  Widget _buildAvatar(String username, String userPic, double size, AvatarFrame frame) {
    final imageUrl = userPic.startsWith('http')
        ? userPic
        : 'https://retroachievements.org${userPic.isNotEmpty ? userPic : '/UserPic/$username.png'}';
    return Container(
      decoration: getAvatarDecoration(
        frame: frame,
        size: size,
        borderColor: Colors.white24,
        borderWidth: 2,
      ),
      child: clipAvatar(
        frame: frame,
        size: size,
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => Container(
            width: size,
            height: size,
            color: Colors.grey[800],
            child: Icon(Icons.person, size: size / 2, color: Colors.grey),
          ),
        ),
      ),
    );
  }

  Widget _buildTrophyRank(int rank, Color rankColor, String formattedScore, bool isCompact) {
    // Position label
    final positionLabel = switch (rank) {
      1 => '1ST PLACE',
      2 => '2ND PLACE',
      3 => '3RD PLACE',
      _ => '#$rank',
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Trophy icon with glow - scaled down for square card
        Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: rankColor.withValues(alpha: 0.4),
                blurRadius: 20,
                spreadRadius: 3,
              ),
            ],
          ),
          child: Icon(
            Icons.emoji_events,
            color: rankColor,
            size: 40,
          ),
        ),
        const SizedBox(height: 6),
        // Position label
        Text(
          positionLabel,
          style: getCardTextStyle(
            fontStyle: settings.fontStyle,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: rankColor,
            letterSpacing: 1.5,
          ),
        ),
        // Score below
        if (formattedScore.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            formattedScore,
            style: getCardTextStyle(
              fontStyle: settings.fontStyle,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.tealAccent,
            ),
          ),
        ],
      ],
    );
  }
}

class GlobalRankCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final ShareCardSettings settings;

  const GlobalRankCard({
    super.key,
    required this.data,
    this.settings = const ShareCardSettings(),
  });

  @override
  Widget build(BuildContext context) {
    final username = data['username'] ?? 'Player';
    final userPic = data['userPic'] ?? '';
    final rank = data['rank'] ?? 0;
    final points = data['points'] ?? 0;
    final truePoints = data['truePoints'] ?? 0;
    final isCompact = settings.layout == CardLayout.compact;

    // Determine rank tier color
    Color rankColor;
    String tierLabel;
    if (rank <= 10) {
      rankColor = Colors.amber;
      tierLabel = 'TOP 10';
    } else if (rank <= 100) {
      rankColor = Colors.deepPurple;
      tierLabel = 'TOP 100';
    } else if (rank <= 1000) {
      rankColor = Colors.blue;
      tierLabel = 'TOP 1K';
    } else if (rank <= 10000) {
      rankColor = Colors.teal;
      tierLabel = 'TOP 10K';
    } else {
      rankColor = Colors.grey;
      tierLabel = 'RANKED';
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Avatar
        _buildAvatar(username, userPic, isCompact ? 50 : 64, settings.avatarFrame),
        SizedBox(height: isCompact ? 10 : 14),

        // Username
        Text(
          username,
          style: getCardTextStyle(
            fontStyle: settings.fontStyle,
            fontSize: isCompact ? 20 : 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: isCompact ? 14 : 20),

        // Tier badge
        Container(
          padding: EdgeInsets.symmetric(horizontal: isCompact ? 12 : 16, vertical: isCompact ? 4 : 6),
          decoration: BoxDecoration(
            color: rankColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: rankColor.withValues(alpha: 0.5)),
          ),
          child: Text(
            tierLabel,
            style: getCardTextStyle(
              fontStyle: settings.fontStyle,
              fontSize: isCompact ? 11 : 13,
              fontWeight: FontWeight.bold,
              color: rankColor,
              letterSpacing: 1.5,
            ),
          ),
        ),
        SizedBox(height: isCompact ? 10 : 14),

        // Global rank display
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '#',
              style: getCardTextStyle(
                fontStyle: settings.fontStyle,
                fontSize: isCompact ? 18 : 24,
                fontWeight: FontWeight.bold,
                color: rankColor,
              ),
            ),
            Text(
              _formatRankWithCommas(rank),
              style: getCardTextStyle(
                fontStyle: settings.fontStyle,
                fontSize: isCompact ? 36 : 48,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        SizedBox(height: isCompact ? 4 : 8),
        Text(
          'GLOBAL RANK',
          style: getCardTextStyle(
            fontStyle: settings.fontStyle,
            fontSize: isCompact ? 11 : 13,
            color: Colors.white70,
            letterSpacing: 2,
          ),
        ),
        SizedBox(height: isCompact ? 16 : 22),

        // Stats row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildStatItem(Icons.stars, _formatNumber(points), 'Points', Colors.amber, isCompact),
            SizedBox(width: isCompact ? 24 : 36),
            _buildStatItem(Icons.military_tech, _formatNumber(truePoints), 'True Points', Colors.purple, isCompact),
          ],
        ),
        SizedBox(height: isCompact ? 14 : 20),

        Branding(fontStyle: settings.fontStyle),
      ],
    );
  }

  Widget _buildAvatar(String username, String userPic, double size, AvatarFrame frame) {
    final imageUrl = userPic.startsWith('http')
        ? userPic
        : 'https://retroachievements.org${userPic.isNotEmpty ? userPic : '/UserPic/$username.png'}';
    return Container(
      decoration: getAvatarDecoration(
        frame: frame,
        size: size,
        borderColor: Colors.white24,
        borderWidth: 3,
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withValues(alpha: 0.3),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: clipAvatar(
        frame: frame,
        size: size,
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => Container(
            width: size,
            height: size,
            color: Colors.grey[800],
            child: Icon(Icons.person, size: size / 2, color: Colors.grey),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label, Color color, bool isCompact) {
    return Column(
      children: [
        Icon(icon, color: color, size: isCompact ? 22 : 28),
        SizedBox(height: isCompact ? 4 : 6),
        Text(
          value,
          style: getCardTextStyle(
            fontStyle: settings.fontStyle,
            fontSize: isCompact ? 18 : 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: getCardTextStyle(
            fontStyle: settings.fontStyle,
            fontSize: isCompact ? 10 : 12,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  String _formatRankWithCommas(int rank) {
    // Format with commas: 60304 -> 60,304
    final str = rank.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  String _formatNumber(dynamic num) {
    if (num == null) return '0';
    final n = int.tryParse(num.toString()) ?? 0;
    if (n >= 1000000) {
      return '${(n / 1000000).toStringAsFixed(1)}M';
    } else if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(1)}K';
    }
    return n.toString();
  }
}
