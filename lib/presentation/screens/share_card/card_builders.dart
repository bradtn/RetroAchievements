import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'share_card_settings.dart';
import 'share_card_widgets.dart';

class ProfileCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final ShareCardSettings settings;

  const ProfileCard({
    super.key,
    required this.data,
    this.settings = const ShareCardSettings(),
  });

  @override
  Widget build(BuildContext context) {
    final username = data['Username'] ?? data['User'] ?? 'Player';
    final points = data['TotalPoints'] ?? 0;
    final truePoints = data['TotalTruePoints'] ?? 0;
    final rank = data['Rank'] ?? '-';
    final userPic = data['UserPic'] ?? '';
    final isCompact = settings.layout == CardLayout.compact;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Avatar
        _buildAvatar(username, userPic, isCompact ? 40 : 50),
        SizedBox(height: isCompact ? 12 : 16),

        // Username
        Text(
          username,
          style: getCardTextStyle(
            fontStyle: settings.fontStyle,
            fontSize: isCompact ? 22 : 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: isCompact ? 2 : 4),
        Text(
          'Rank #$rank',
          style: getCardTextStyle(
            fontStyle: settings.fontStyle,
            fontSize: isCompact ? 14 : 16,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
        SizedBox(height: isCompact ? 16 : 24),

        // Stats
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStatBadge(
              Icons.stars,
              formatNumber(points),
              'Points',
              Colors.amber,
              isCompact,
            ),
            if (!isCompact)
              _buildStatBadge(
                Icons.military_tech,
                formatNumber(truePoints),
                'True Points',
                Colors.purple[200]!,
                isCompact,
              ),
          ],
        ),
        SizedBox(height: isCompact ? 16 : 24),

        // Branding
        const Branding(),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
          ),
        ],
      ),
      child: clipAvatar(
        frame: settings.avatarFrame,
        size: avatarSize,
        child: content,
      ),
    );
  }

  Widget _buildAvatarPlaceholder(String username, double size) {
    return Container(
      width: size,
      height: size,
      color: Colors.grey[800],
      child: Center(
        child: Text(
          username.isNotEmpty ? username[0].toUpperCase() : '?',
          style: TextStyle(fontSize: size * 0.36, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildStatBadge(IconData icon, String value, String label, Color color, bool isCompact) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(isCompact ? 8 : 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: color, size: isCompact ? 22 : 28),
        ),
        SizedBox(height: isCompact ? 6 : 8),
        Text(
          value,
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
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
      ],
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
    final isCompact = settings.layout == CardLayout.compact;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Game icon
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 10,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: CachedNetworkImage(
              imageUrl: 'https://retroachievements.org$imageIcon',
              width: isCompact ? 72 : 96,
              height: isCompact ? 72 : 96,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Container(
                width: isCompact ? 72 : 96,
                height: isCompact ? 72 : 96,
                color: Colors.grey[800],
                child: Icon(Icons.games, size: isCompact ? 36 : 48, color: Colors.white),
              ),
            ),
          ),
        ),
        SizedBox(height: isCompact ? 12 : 16),

        // Mastery badge
        if (isMastered)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            margin: EdgeInsets.only(bottom: isCompact ? 6 : 8),
            decoration: BoxDecoration(
              color: Colors.amber,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.workspace_premium, color: Colors.black, size: 16),
                const SizedBox(width: 4),
                Text(
                  'MASTERED',
                  style: getCardTextStyle(
                    fontStyle: settings.fontStyle,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),

        // Title
        Text(
          title,
          style: getCardTextStyle(
            fontStyle: settings.fontStyle,
            fontSize: isCompact ? 18 : 22,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: isCompact ? 6 : 8),
        if (consoleName.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              consoleName,
              style: getCardTextStyle(
                fontStyle: settings.fontStyle,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.blue,
              ),
            ),
          ),
        SizedBox(height: isCompact ? 14 : 20),

        // Progress bar
        Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: isCompact ? 10 : 12,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation(
                  isMastered ? Colors.amber : Colors.green,
                ),
              ),
            ),
            SizedBox(height: isCompact ? 6 : 8),
            Text(
              '$earned / $total achievements (${(progress * 100).toStringAsFixed(0)}%)',
              style: getCardTextStyle(
                fontStyle: settings.fontStyle,
                fontSize: isCompact ? 12 : 14,
              ),
            ),
          ],
        ),
        if (!isCompact) ...[
          const SizedBox(height: 16),
          // Points
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.stars, color: Colors.amber[300], size: 20),
              const SizedBox(width: 4),
              Text(
                '$earnedPoints / $points points',
                style: getCardTextStyle(
                  fontStyle: settings.fontStyle,
                  fontSize: 14,
                  color: Colors.amber[300]!,
                ),
              ),
            ],
          ),
        ],
        SizedBox(height: isCompact ? 14 : 20),

        // Player info
        PlayerTag(username: username),
        SizedBox(height: isCompact ? 12 : 16),

        const Branding(),
      ],
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
    final isCompact = settings.layout == CardLayout.compact;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Game info row at top with cover art
        if (!isCompact && (gameTitle.isNotEmpty || gameIcon.isNotEmpty)) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (gameIcon.isNotEmpty)
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: CachedNetworkImage(
                      imageUrl: 'https://retroachievements.org$gameIcon',
                      width: 28,
                      height: 28,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        width: 28,
                        height: 28,
                        color: Colors.grey[700],
                        child: const Icon(Icons.games, size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              if (gameIcon.isNotEmpty && gameTitle.isNotEmpty)
                const SizedBox(width: 8),
              if (gameTitle.isNotEmpty)
                Flexible(
                  child: Column(
                    children: [
                      Text(
                        gameTitle,
                        style: getCardTextStyle(
                          fontStyle: settings.fontStyle,
                          fontSize: 12,
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
                            fontSize: 10,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                          textAlign: TextAlign.center,
                        ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],

        // Badge with lock overlay for unearned
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
                      blurRadius: 20,
                      spreadRadius: 2,
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
                    width: isCompact ? 80 : 100,
                    height: isCompact ? 80 : 100,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      width: isCompact ? 80 : 100,
                      height: isCompact ? 80 : 100,
                      color: Colors.grey[800],
                      child: Icon(Icons.emoji_events, size: isCompact ? 36 : 48, color: Colors.amber),
                    ),
                  ),
                ),
              ),
            ),
            // Lock icon overlay for unearned
            if (!isEarned)
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock, color: Colors.white, size: 20),
              ),
          ],
        ),
        SizedBox(height: isCompact ? 8 : 12),

        // Earned/Not earned status badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: isEarned
                ? Colors.green.withValues(alpha: 0.3)
                : Colors.red.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
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
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                isEarned ? 'UNLOCKED' : 'NOT YET UNLOCKED',
                style: getCardTextStyle(
                  fontStyle: settings.fontStyle,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isEarned ? Colors.green : Colors.red[300]!,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: isCompact ? 10 : 14),

        // Hardcore badge
        if (isHardcore)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            margin: EdgeInsets.only(bottom: isCompact ? 6 : 8),
            decoration: BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'HARDCORE',
              style: getCardTextStyle(
                fontStyle: settings.fontStyle,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

        // Title
        Text(
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
        if (!isCompact) ...[
          const SizedBox(height: 6),
          // Description
          Text(
            description,
            style: getCardTextStyle(
              fontStyle: settings.fontStyle,
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.8),
            ),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        SizedBox(height: isCompact ? 10 : 14),

        // Points and rarity
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.stars, color: Colors.amber, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '$points pts',
                    style: getCardTextStyle(
                      fontStyle: settings.fontStyle,
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
        SizedBox(height: isCompact ? 12 : 16),

        // User info row
        if (username.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
                  ),
                  child: ClipOval(
                    child: userPic.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: 'https://retroachievements.org$userPic',
                            width: 28,
                            height: 28,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => _buildUserPlaceholder(username),
                          )
                        : _buildUserPlaceholder(username),
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
          ),
          SizedBox(height: isCompact ? 12 : 16),
        ],

        const Branding(),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: rarityColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
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
          Icon(Icons.people, color: rarityColor.withValues(alpha: 0.7), size: 12),
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

        const Branding(),
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
      mainAxisSize: MainAxisSize.min,
      children: [
        // Milestone badge
        Container(
          width: isCompact ? 80 : 100,
          height: isCompact ? 80 : 100,
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
            size: isCompact ? 36 : 48,
            color: milestoneColor.withValues(alpha: isEarned ? 1.0 : 0.7),
          ),
        ),
        SizedBox(height: isCompact ? 12 : 16),

        // Category chip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: milestoneColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            category,
            style: getCardTextStyle(
              fontStyle: settings.fontStyle,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: milestoneColor,
            ),
          ),
        ),
        SizedBox(height: isCompact ? 8 : 12),

        // Title
        Text(
          title,
          style: getCardTextStyle(
            fontStyle: settings.fontStyle,
            fontSize: isCompact ? 18 : 24,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        if (!isCompact) ...[
          const SizedBox(height: 8),
          // Description
          Text(
            description,
            style: getCardTextStyle(
              fontStyle: settings.fontStyle,
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
        SizedBox(height: isCompact ? 14 : 20),

        // Earned badge or progress
        if (isEarned)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.green.withValues(alpha: 0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 18),
                const SizedBox(width: 6),
                Text(
                  'EARNED',
                  style: getCardTextStyle(
                    fontStyle: settings.fontStyle,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          )
        else
          Column(
            children: [
              Text(
                '$currentValue / $requirement',
                style: getCardTextStyle(
                  fontStyle: settings.fontStyle,
                  fontSize: isCompact ? 14 : 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 200,
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress,
                  child: Container(
                    decoration: BoxDecoration(
                      color: milestoneColor,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${(progress * 100).toInt()}% complete',
                style: getCardTextStyle(
                  fontStyle: settings.fontStyle,
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        SizedBox(height: isCompact ? 14 : 20),

        // User info
        _buildUserInfo(username, userPic),
        SizedBox(height: isCompact ? 14 : 20),

        const Branding(),
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
      mainAxisSize: MainAxisSize.min,
      children: [
        // Game/Award icon
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: awardColor, width: 4),
            boxShadow: [
              BoxShadow(
                color: awardColor.withValues(alpha: 0.4),
                blurRadius: 20,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: CachedNetworkImage(
              imageUrl: 'https://retroachievements.org$imageIcon',
              width: isCompact ? 90 : 120,
              height: isCompact ? 90 : 120,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Container(
                width: isCompact ? 90 : 120,
                height: isCompact ? 90 : 120,
                color: Colors.grey[800],
                child: Icon(Icons.emoji_events, size: isCompact ? 42 : 56, color: awardColor),
              ),
            ),
          ),
        ),
        SizedBox(height: isCompact ? 12 : 16),

        // Award type badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: awardColor.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: awardColor.withValues(alpha: 0.6)),
          ),
          child: Text(
            awardType.toUpperCase(),
            style: getCardTextStyle(
              fontStyle: settings.fontStyle,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: awardColor,
            ),
          ),
        ),
        SizedBox(height: isCompact ? 8 : 12),

        // Title
        Text(
          title,
          style: getCardTextStyle(
            fontStyle: settings.fontStyle,
            fontSize: isCompact ? 18 : 22,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (!isCompact) ...[
          const SizedBox(height: 6),
          // Console
          Text(
            consoleName,
            style: getCardTextStyle(
              fontStyle: settings.fontStyle,
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          if (awardedAt.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Awarded: ${_formatAwardDate(awardedAt)}',
              style: getCardTextStyle(
                fontStyle: settings.fontStyle,
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ],
        ],
        SizedBox(height: isCompact ? 14 : 20),

        // User info
        _buildUserInfo(username, userPic),
        SizedBox(height: isCompact ? 14 : 20),

        const Branding(),
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

        const Branding(),
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
        _buildAvatar(username, userPic, isCompact ? 35 : 45),
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

        const Branding(),
      ],
    );
  }

  Widget _buildAvatar(String username, String userPic, double size) {
    final imageUrl = userPic.startsWith('http')
        ? userPic
        : 'https://retroachievements.org${userPic.isNotEmpty ? userPic : '/UserPic/$username.png'}';
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24, width: 2),
      ),
      child: ClipOval(
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
        _buildAvatar(username, userPic, isCompact ? 35 : 45),
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

        const Branding(),
      ],
    );
  }

  Widget _buildAvatar(String username, String userPic, double size) {
    final imageUrl = userPic.startsWith('http')
        ? userPic
        : 'https://retroachievements.org${userPic.isNotEmpty ? userPic : '/UserPic/$username.png'}';
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24, width: 2),
      ),
      child: ClipOval(
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
    final leaderboardTitle = data['leaderboardTitle'] ?? 'Leaderboard';
    final rank = data['rank'] ?? 0;
    final formattedScore = data['formattedScore'] ?? '';
    final isCompact = settings.layout == CardLayout.compact;

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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Game icon and title
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: 'https://retroachievements.org$gameIcon',
                width: isCompact ? 36 : 48,
                height: isCompact ? 36 : 48,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  width: isCompact ? 36 : 48,
                  height: isCompact ? 36 : 48,
                  color: Colors.grey[800],
                  child: Icon(Icons.videogame_asset, size: isCompact ? 20 : 28, color: Colors.grey),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                gameTitle,
                style: getCardTextStyle(
                  fontStyle: settings.fontStyle,
                  fontSize: isCompact ? 14 : 18,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        SizedBox(height: isCompact ? 12 : 16),

        // Leaderboard title
        Container(
          padding: EdgeInsets.symmetric(horizontal: isCompact ? 12 : 16, vertical: isCompact ? 6 : 8),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.leaderboard, color: Colors.amber, size: isCompact ? 16 : 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  leaderboardTitle,
                  style: getCardTextStyle(
                    fontStyle: settings.fontStyle,
                    fontSize: isCompact ? 12 : 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: isCompact ? 14 : 20),

        // User avatar
        _buildAvatar(username, userPic, isCompact ? 40 : 50),
        SizedBox(height: isCompact ? 8 : 12),

        // Username
        Text(
          username,
          style: getCardTextStyle(
            fontStyle: settings.fontStyle,
            fontSize: isCompact ? 16 : 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: isCompact ? 12 : 16),

        // Rank display - fancy for top 3, simple for others
        if (rank <= 3) ...[
          // Trophy layout for top 3
          _buildTrophyRank(rank, rankColor, formattedScore, isCompact),
        ] else ...[
          // Standard rank display
          Container(
            padding: EdgeInsets.symmetric(horizontal: isCompact ? 20 : 28, vertical: isCompact ? 10 : 14),
            decoration: BoxDecoration(
              color: rankColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: rankColor.withValues(alpha: 0.5), width: 2),
            ),
            child: Text(
              '#$rank',
              style: getCardTextStyle(
                fontStyle: settings.fontStyle,
                fontSize: isCompact ? 32 : 42,
                fontWeight: FontWeight.bold,
                color: rankColor,
              ),
            ),
          ),
          // Score for non-trophy ranks
          if (formattedScore.isNotEmpty) ...[
            SizedBox(height: isCompact ? 10 : 14),
            Text(
              formattedScore,
              style: getCardTextStyle(
                fontStyle: settings.fontStyle,
                fontSize: isCompact ? 18 : 24,
                fontWeight: FontWeight.w500,
                color: Colors.tealAccent,
              ),
            ),
          ],
        ],
        SizedBox(height: isCompact ? 14 : 20),

        const Branding(),
      ],
    );
  }

  Widget _buildAvatar(String username, String userPic, double size) {
    final imageUrl = userPic.startsWith('http')
        ? userPic
        : 'https://retroachievements.org${userPic.isNotEmpty ? userPic : '/UserPic/$username.png'}';
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24, width: 2),
      ),
      child: ClipOval(
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
      children: [
        // Large trophy icon with glow
        Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: rankColor.withValues(alpha: 0.5),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Icon(
            Icons.emoji_events,
            color: rankColor,
            size: isCompact ? 56 : 72,
          ),
        ),
        SizedBox(height: isCompact ? 8 : 12),
        // Position label
        Text(
          positionLabel,
          style: getCardTextStyle(
            fontStyle: settings.fontStyle,
            fontSize: isCompact ? 20 : 26,
            fontWeight: FontWeight.bold,
            color: rankColor,
            letterSpacing: 2,
          ),
        ),
        // Score below
        if (formattedScore.isNotEmpty) ...[
          SizedBox(height: isCompact ? 8 : 12),
          Text(
            formattedScore,
            style: getCardTextStyle(
              fontStyle: settings.fontStyle,
              fontSize: isCompact ? 16 : 20,
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
        _buildAvatar(username, userPic, isCompact ? 50 : 64),
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

        const Branding(),
      ],
    );
  }

  Widget _buildAvatar(String username, String userPic, double size) {
    final imageUrl = userPic.startsWith('http')
        ? userPic
        : 'https://retroachievements.org${userPic.isNotEmpty ? userPic : '/UserPic/$username.png'}';
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withValues(alpha: 0.3),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipOval(
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
