import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'share_card_widgets.dart';

class ProfileCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const ProfileCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final username = data['Username'] ?? data['User'] ?? 'Player';
    final points = data['TotalPoints'] ?? 0;
    final truePoints = data['TotalTruePoints'] ?? 0;
    final rank = data['Rank'] ?? '-';
    final userPic = data['UserPic'] ?? '';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Avatar
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 10,
              ),
            ],
          ),
          child: CircleAvatar(
            radius: 50,
            backgroundImage: userPic.isNotEmpty
                ? CachedNetworkImageProvider('https://retroachievements.org$userPic')
                : null,
            backgroundColor: Colors.grey[800],
            child: userPic.isEmpty
                ? Text(username[0].toUpperCase(), style: const TextStyle(fontSize: 36))
                : null,
          ),
        ),
        const SizedBox(height: 16),

        // Username
        Text(
          username,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Rank #$rank',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 24),

        // Stats
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            StatBadge(
              icon: Icons.stars,
              value: formatNumber(points),
              label: 'Points',
              color: Colors.amber,
            ),
            StatBadge(
              icon: Icons.military_tech,
              value: formatNumber(truePoints),
              label: 'True Points',
              color: Colors.purple[200]!,
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Branding
        const Branding(),
      ],
    );
  }
}

class GameCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String username;

  const GameCard({super.key, required this.data, required this.username});

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
              width: 96,
              height: 96,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Container(
                width: 96,
                height: 96,
                color: Colors.grey[800],
                child: const Icon(Icons.games, size: 48, color: Colors.white),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Mastery badge
        if (isMastered)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.amber,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.workspace_premium, color: Colors.black, size: 16),
                SizedBox(width: 4),
                Text(
                  'MASTERED',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

        // Title
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          consoleName,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 20),

        // Progress bar
        Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 12,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation(
                  isMastered ? Colors.amber : Colors.green,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$earned / $total achievements (${(progress * 100).toStringAsFixed(0)}%)',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Points
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.stars, color: Colors.amber[300], size: 20),
            const SizedBox(width: 4),
            Text(
              '$earnedPoints / $points points',
              style: TextStyle(color: Colors.amber[300], fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Player info
        PlayerTag(username: username),
        const SizedBox(height: 16),

        const Branding(),
      ],
    );
  }
}

class AchievementCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const AchievementCard({super.key, required this.data});

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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Game info row at top with cover art
        if (gameTitle.isNotEmpty || gameIcon.isNotEmpty) ...[
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
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (consoleName.isNotEmpty)
                        Text(
                          consoleName,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 10,
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
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      width: 100,
                      height: 100,
                      color: Colors.grey[800],
                      child: const Icon(Icons.emoji_events, size: 48, color: Colors.amber),
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
        const SizedBox(height: 12),

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
                style: TextStyle(
                  color: isEarned ? Colors.green : Colors.red[300],
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Hardcore badge
        if (isHardcore)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'HARDCORE',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),

        // Title
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),

        // Description
        Text(
          description,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 13,
          ),
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 14),

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
                    style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            if (unlockPercent != null && unlockPercent > 0)
              _buildRarityBadge(unlockPercent),
          ],
        ),
        const SizedBox(height: 16),

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
                            errorWidget: (_, __, ___) => Container(
                              width: 28,
                              height: 28,
                              color: Colors.grey[700],
                              child: Center(
                                child: Text(
                                  username.isNotEmpty ? username[0].toUpperCase() : '?',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  username,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        const Branding(),
      ],
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
            style: TextStyle(color: rarityColor, fontWeight: FontWeight.bold, fontSize: 12),
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

  const ComparisonCard({super.key, required this.data});

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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // VS Header
        Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: winner == 'me' ? Colors.green : Colors.white.withValues(alpha: 0.5),
                        width: winner == 'me' ? 3 : 2,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 35,
                      backgroundImage: myPic.isNotEmpty
                          ? CachedNetworkImageProvider('https://retroachievements.org$myPic')
                          : null,
                      backgroundColor: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    myName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (winner == 'me')
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'WINNER',
                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Text(
                'VS',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: winner == 'other' ? Colors.red : Colors.white.withValues(alpha: 0.5),
                        width: winner == 'other' ? 3 : 2,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 35,
                      backgroundImage: otherPic.isNotEmpty
                          ? CachedNetworkImageProvider('https://retroachievements.org$otherPic')
                          : null,
                      backgroundColor: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    otherName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (winner == 'other')
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'WINNER',
                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Stats comparison
        ComparisonStatRow(
          label: 'Points',
          myValue: formatNumber(myPoints),
          otherValue: formatNumber(otherPoints),
          myWins: myPtsNum > otherPtsNum,
          otherWins: otherPtsNum > myPtsNum,
        ),
        const SizedBox(height: 8),
        ComparisonStatRow(
          label: 'True Points',
          myValue: formatNumber(myTruePoints),
          otherValue: formatNumber(otherTruePoints),
          myWins: (int.tryParse(myTruePoints.toString()) ?? 0) > (int.tryParse(otherTruePoints.toString()) ?? 0),
          otherWins: (int.tryParse(otherTruePoints.toString()) ?? 0) > (int.tryParse(myTruePoints.toString()) ?? 0),
        ),
        const SizedBox(height: 24),

        const Branding(),
      ],
    );
  }
}

class MilestoneCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const MilestoneCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final title = data['title'] ?? 'Milestone';
    final description = data['description'] ?? '';
    final category = data['category'] ?? '';
    final username = data['username'] ?? 'Player';
    final userPic = data['userPic'] ?? '';
    final iconCode = data['iconCode'] as int? ?? Icons.emoji_events.codePoint;
    final colorValue = data['colorValue'] as int? ?? Colors.amber.value;
    final milestoneColor = Color(colorValue);
    final isEarned = data['isEarned'] == true;
    final currentValue = data['currentValue'] as int? ?? 0;
    final requirement = data['requirement'] as int? ?? 1;
    final progress = requirement > 0 ? (currentValue / requirement).clamp(0.0, 1.0) : 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Milestone badge
        Container(
          width: 100,
          height: 100,
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
            size: 48,
            color: milestoneColor.withValues(alpha: isEarned ? 1.0 : 0.7),
          ),
        ),
        const SizedBox(height: 16),

        // Category chip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: milestoneColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            category,
            style: TextStyle(
              color: milestoneColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Title
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),

        // Description
        Text(
          description,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),

        // Earned badge or progress
        if (isEarned)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.green.withValues(alpha: 0.5)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 18),
                SizedBox(width: 6),
                Text(
                  'EARNED',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          )
        else
          Column(
            children: [
              // Progress text
              Text(
                '$currentValue / $requirement',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              // Progress bar
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
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        const SizedBox(height: 20),

        // User info
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 14,
                backgroundImage: userPic.isNotEmpty
                    ? CachedNetworkImageProvider('https://retroachievements.org$userPic')
                    : null,
                backgroundColor: Colors.grey[700],
                child: userPic.isEmpty
                    ? Text(username[0].toUpperCase(), style: const TextStyle(fontSize: 12))
                    : null,
              ),
              const SizedBox(width: 8),
              Text(
                username,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        const Branding(),
      ],
    );
  }
}

class RAAwardCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const RAAwardCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final title = data['title'] ?? 'Award';
    final consoleName = data['consoleName'] ?? '';
    final awardType = data['awardType'] ?? 'Award';
    final imageIcon = data['imageIcon'] ?? '';
    final awardedAt = data['awardedAt'] ?? '';
    final username = data['username'] ?? 'Player';
    final userPic = data['userPic'] ?? '';
    final colorValue = data['colorValue'] as int? ?? Colors.amber.value;
    final awardColor = Color(colorValue);

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
              width: 120,
              height: 120,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Container(
                width: 120,
                height: 120,
                color: Colors.grey[800],
                child: Icon(Icons.emoji_events, size: 56, color: awardColor),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

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
            style: TextStyle(
              color: awardColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Title
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),

        // Console
        Text(
          consoleName,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 14,
          ),
        ),

        if (awardedAt.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'Awarded: ${_formatAwardDate(awardedAt)}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
            ),
          ),
        ],
        const SizedBox(height: 20),

        // User info
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 14,
                backgroundImage: userPic.isNotEmpty
                    ? CachedNetworkImageProvider('https://retroachievements.org$userPic')
                    : null,
                backgroundColor: Colors.grey[700],
                child: userPic.isEmpty
                    ? Text(username.isNotEmpty ? username[0].toUpperCase() : '?',
                        style: const TextStyle(fontSize: 12))
                    : null,
              ),
              const SizedBox(width: 8),
              Text(
                username,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        const Branding(),
      ],
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

  const StreakCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final currentStreak = data['currentStreak'] as int? ?? 0;
    final bestStreak = data['bestStreak'] as int? ?? 0;
    final username = data['username'] as String? ?? 'Player';
    final isActive = data['isActive'] as bool? ?? false;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Fire icon
        Container(
          width: 100,
          height: 100,
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
          child: const Icon(
            Icons.local_fire_department,
            size: 56,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 20),

        // Current streak
        Text(
          '$currentStreak',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 64,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          'DAY STREAK',
          style: TextStyle(
            color: Colors.orange.shade300,
            fontSize: 18,
            fontWeight: FontWeight.bold,
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
            style: TextStyle(
              color: isActive ? Colors.green.shade300 : Colors.grey.shade400,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Best streak
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
                style: TextStyle(
                  color: Colors.amber.shade300,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Username
        Text(
          username,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 20),

        const Branding(),
      ],
    );
  }
}
