import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../providers/auth_provider.dart';
import '../widgets/premium_gate.dart';

enum ShareCardType { profile, game, achievement, comparison, milestone, raAward, streak }

class ShareCardScreen extends ConsumerStatefulWidget {
  final ShareCardType type;
  final Map<String, dynamic> data;

  const ShareCardScreen({
    super.key,
    required this.type,
    required this.data,
  });

  @override
  ConsumerState<ShareCardScreen> createState() => _ShareCardScreenState();
}

class _ShareCardScreenState extends ConsumerState<ShareCardScreen> {
  final GlobalKey _cardKey = GlobalKey();
  int _selectedStyle = 0;
  bool _isGenerating = false;

  final List<_CardStyle> _styles = [
    _CardStyle('Classic', [Color(0xFF1a1a2e), Color(0xFF16213e)]),
    _CardStyle('Retro', [Color(0xFF2d132c), Color(0xFF801336)]),
    _CardStyle('Neon', [Color(0xFF0f0c29), Color(0xFF302b63)]),
    _CardStyle('Forest', [Color(0xFF134e5e), Color(0xFF71b280)]),
    _CardStyle('Sunset', [Color(0xFFff6b6b), Color(0xFFfeca57)]),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Share Card'),
      ),
      body: PremiumGate(
        featureName: 'Share Cards',
        description: 'Create beautiful cards to share your achievements, stats, and milestones on social media.',
        icon: Icons.share,
        child: _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Column(
      children: [
        // Share button at top
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isGenerating ? null : _shareCard,
              icon: _isGenerating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.share),
              label: const Text('Share Card'),
            ),
          ),
        ),
        // Card preview
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: RepaintBoundary(
                key: _cardKey,
                child: _buildCard(),
              ),
            ),
          ),
        ),

        // Style selector
        Container(
          padding: EdgeInsets.only(
            top: 12,
            bottom: 12 + MediaQuery.of(context).viewPadding.bottom,
          ),
          child: SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _styles.length,
              itemBuilder: (ctx, i) => _StyleButton(
                style: _styles[i],
                isSelected: _selectedStyle == i,
                onTap: () => setState(() => _selectedStyle = i),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCard() {
    final style = _styles[_selectedStyle];

    return Container(
      width: 350,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: style.colors,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: style.colors.first.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Pattern overlay
            Positioned.fill(
              child: CustomPaint(
                painter: _PatternPainter(),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(24),
              child: switch (widget.type) {
                ShareCardType.profile => _buildProfileCard(),
                ShareCardType.game => _buildGameCard(),
                ShareCardType.achievement => _buildAchievementCard(),
                ShareCardType.comparison => _buildComparisonCard(),
                ShareCardType.milestone => _buildMilestoneCard(),
                ShareCardType.raAward => _buildRAAwardCard(),
                ShareCardType.streak => _buildStreakCard(),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    final username = widget.data['User'] ?? 'Player';
    final points = widget.data['TotalPoints'] ?? 0;
    final truePoints = widget.data['TotalTruePoints'] ?? 0;
    final rank = widget.data['Rank'] ?? '-';
    final userPic = widget.data['UserPic'] ?? '';

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
            _StatBadge(
              icon: Icons.stars,
              value: _formatNumber(points),
              label: 'Points',
              color: Colors.amber,
            ),
            _StatBadge(
              icon: Icons.military_tech,
              value: _formatNumber(truePoints),
              label: 'True Points',
              color: Colors.purple[200]!,
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Branding
        _buildBranding(),
      ],
    );
  }

  Widget _buildGameCard() {
    final title = widget.data['Title'] ?? 'Game';
    final consoleName = widget.data['ConsoleName'] ?? '';
    final imageIcon = widget.data['ImageIcon'] ?? '';
    final earned = widget.data['NumAwardedToUser'] ?? widget.data['NumAchieved'] ?? 0;
    final total = widget.data['NumAchievements'] ?? widget.data['NumPossibleAchievements'] ?? 0;
    final points = widget.data['Points'] ?? widget.data['PossibleScore'] ?? 0;
    final earnedPoints = widget.data['ScoreAchieved'] ?? 0;
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
        _buildPlayerTag(),
        const SizedBox(height: 16),

        _buildBranding(),
      ],
    );
  }

  Widget _buildAchievementCard() {
    final title = widget.data['Title'] ?? 'Achievement';
    final description = widget.data['Description'] ?? '';
    final points = widget.data['Points'] ?? 0;
    final badgeName = widget.data['BadgeName'] ?? '';
    final gameTitle = widget.data['GameTitle'] ?? '';
    final gameIcon = widget.data['GameIcon'] ?? '';
    final consoleName = widget.data['ConsoleName'] ?? widget.data['consoleName'] ?? '';
    final username = widget.data['Username'] ?? '';
    final userPic = widget.data['UserPic'] ?? '';
    final isEarned = widget.data['IsEarned'] == true;
    final unlockPercent = widget.data['UnlockPercent'];
    final rarityLabel = widget.data['RarityLabel'] ?? '';
    final isHardcore = widget.data['HardcoreMode'] == 1;

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
              Builder(
                builder: (context) {
                  // Determine rarity based on unlock percent
                  final IconData rarityIcon;
                  final Color rarityColor;
                  final String rarityText;

                  if (unlockPercent < 5) {
                    rarityIcon = Icons.diamond;
                    rarityColor = Colors.red;
                    rarityText = 'Ultra Rare';
                  } else if (unlockPercent < 15) {
                    rarityIcon = Icons.star;
                    rarityColor = Colors.purple;
                    rarityText = 'Rare';
                  } else if (unlockPercent < 40) {
                    rarityIcon = Icons.hexagon;
                    rarityColor = Colors.blue;
                    rarityText = 'Uncommon';
                  } else {
                    rarityIcon = Icons.circle;
                    rarityColor = Colors.grey;
                    rarityText = 'Common';
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
                },
              ),
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

        _buildBranding(),
      ],
    );
  }

  Widget _buildComparisonCard() {
    final myProfile = widget.data['myProfile'] as Map<String, dynamic>? ?? {};
    final otherProfile = widget.data['otherProfile'] as Map<String, dynamic>? ?? {};

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
        _ComparisonStatRow(
          label: 'Points',
          myValue: _formatNumber(myPoints),
          otherValue: _formatNumber(otherPoints),
          myWins: myPtsNum > otherPtsNum,
          otherWins: otherPtsNum > myPtsNum,
        ),
        const SizedBox(height: 8),
        _ComparisonStatRow(
          label: 'True Points',
          myValue: _formatNumber(myTruePoints),
          otherValue: _formatNumber(otherTruePoints),
          myWins: (int.tryParse(myTruePoints.toString()) ?? 0) > (int.tryParse(otherTruePoints.toString()) ?? 0),
          otherWins: (int.tryParse(otherTruePoints.toString()) ?? 0) > (int.tryParse(myTruePoints.toString()) ?? 0),
        ),
        const SizedBox(height: 24),

        _buildBranding(),
      ],
    );
  }

  Widget _buildMilestoneCard() {
    final title = widget.data['title'] ?? 'Milestone';
    final description = widget.data['description'] ?? '';
    final category = widget.data['category'] ?? '';
    final username = widget.data['username'] ?? 'Player';
    final userPic = widget.data['userPic'] ?? '';
    final iconCode = widget.data['iconCode'] as int? ?? Icons.emoji_events.codePoint;
    final colorValue = widget.data['colorValue'] as int? ?? Colors.amber.value;
    final milestoneColor = Color(colorValue);
    final isEarned = widget.data['isEarned'] == true;
    final currentValue = widget.data['currentValue'] as int? ?? 0;
    final requirement = widget.data['requirement'] as int? ?? 1;
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

        _buildBranding(),
      ],
    );
  }

  Widget _buildRAAwardCard() {
    final title = widget.data['title'] ?? 'Award';
    final consoleName = widget.data['consoleName'] ?? '';
    final awardType = widget.data['awardType'] ?? 'Award';
    final imageIcon = widget.data['imageIcon'] ?? '';
    final awardedAt = widget.data['awardedAt'] ?? '';
    final username = widget.data['username'] ?? 'Player';
    final userPic = widget.data['userPic'] ?? '';
    final colorValue = widget.data['colorValue'] as int? ?? Colors.amber.value;
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

        _buildBranding(),
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

  Widget _buildStreakCard() {
    final currentStreak = widget.data['currentStreak'] as int? ?? 0;
    final bestStreak = widget.data['bestStreak'] as int? ?? 0;
    final username = widget.data['username'] as String? ?? 'Player';
    final isActive = widget.data['isActive'] as bool? ?? false;

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
          currentStreak == 1 ? 'DAY STREAK' : 'DAY STREAK',
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

        _buildBranding(),
      ],
    );
  }

  Widget _buildPlayerTag() {
    final authState = ref.read(authProvider);
    final username = authState.username ?? 'Player';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundImage: CachedNetworkImageProvider(
              'https://retroachievements.org/UserPic/$username.png',
            ),
            backgroundColor: Colors.grey[700],
            onBackgroundImageError: (_, __) {},
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
    );
  }

  Widget _buildBranding() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.videogame_asset, color: Colors.white.withValues(alpha: 0.5), size: 16),
        const SizedBox(width: 6),
        Text(
          'RetroTracker',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          ' • ',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
        ),
        Text(
          'retroachievements.org',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 12,
          ),
        ),
      ],
    );
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

  Future<void> _shareCard() async {
    setState(() => _isGenerating = true);

    try {
      // Capture the widget as image
      final boundary = _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Could not capture card');
      }

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Could not convert to image');
      }

      final bytes = byteData.buffer.asUint8List();

      // Save to temp file
      final tempDir = await getTemporaryDirectory();
      final fileName = 'retrotracker_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(bytes);

      // Share
      await Share.shareXFiles(
        [XFile(file.path)],
        text: _getShareText(),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  String _getShareText() {
    switch (widget.type) {
      case ShareCardType.profile:
        final username = widget.data['User'] ?? 'Player';
        final points = widget.data['TotalPoints'] ?? 0;
        return 'Check out my RetroAchievements profile! $points points 🎮 #RetroAchievements #RetroTracker';
      case ShareCardType.game:
        final title = widget.data['Title'] ?? 'Game';
        final earned = widget.data['NumAwardedToUser'] ?? widget.data['NumAchieved'] ?? 0;
        final total = widget.data['NumAchievements'] ?? widget.data['NumPossibleAchievements'] ?? 0;
        return 'Playing $title - $earned/$total achievements! 🎮 #RetroAchievements #RetroTracker';
      case ShareCardType.achievement:
        final title = widget.data['Title'] ?? 'Achievement';
        final gameTitle = widget.data['GameTitle'] ?? '';
        return 'Just unlocked "$title" in $gameTitle! 🏆 #RetroAchievements #RetroTracker';
      case ShareCardType.comparison:
        final myProfile = widget.data['myProfile'] as Map<String, dynamic>? ?? {};
        final otherProfile = widget.data['otherProfile'] as Map<String, dynamic>? ?? {};
        final myName = myProfile['User'] ?? 'Me';
        final otherName = otherProfile['User'] ?? 'Opponent';
        return 'Check out my comparison vs $otherName on RetroAchievements! ⚔️ #RetroAchievements #RetroTracker';
      case ShareCardType.milestone:
        final goalTitle = widget.data['title'] ?? 'Goal';
        final username = widget.data['username'] ?? 'Player';
        return '$username completed the "$goalTitle" goal! 🏅 #RetroAchievements #RetroTracker';
      case ShareCardType.raAward:
        final awardTitle = widget.data['title'] ?? 'Game';
        final awardType = widget.data['awardType'] ?? 'Award';
        final username = widget.data['username'] ?? 'Player';
        return '$username earned $awardType on $awardTitle! 🏆 #RetroAchievements #RetroTracker';
      case ShareCardType.streak:
        final currentStreak = widget.data['currentStreak'] ?? 0;
        final username = widget.data['username'] ?? 'Player';
        return '$username is on a $currentStreak day streak! 🔥 #RetroAchievements #RetroTracker';
    }
  }
}

class _CardStyle {
  final String name;
  final List<Color> colors;

  _CardStyle(this.name, this.colors);
}

class _StyleButton extends StatelessWidget {
  final _CardStyle style;
  final bool isSelected;
  final VoidCallback onTap;

  const _StyleButton({
    required this.style,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 60,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: style.colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: Colors.white, width: 2)
              : null,
        ),
        child: Center(
          child: Text(
            style.name,
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatBadge({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _ComparisonStatRow extends StatelessWidget {
  final String label;
  final String myValue;
  final String otherValue;
  final bool myWins;
  final bool otherWins;

  const _ComparisonStatRow({
    required this.label,
    required this.myValue,
    required this.otherValue,
    required this.myWins,
    required this.otherWins,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              myValue,
              style: TextStyle(
                color: myWins ? Colors.green : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
            ),
          ),
          Expanded(
            child: Text(
              otherValue,
              style: TextStyle(
                color: otherWins ? Colors.red : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _PatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..strokeWidth = 1;

    // Draw diagonal lines
    for (var i = -size.height; i < size.width + size.height; i += 20) {
      canvas.drawLine(
        Offset(i.toDouble(), 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
