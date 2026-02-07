import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../providers/auth_provider.dart';

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
        actions: [
          TextButton.icon(
            onPressed: _isGenerating ? null : _shareCard,
            icon: _isGenerating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.share),
            label: const Text('Share'),
          ),
        ],
      ),
      body: Column(
        children: [
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
      ),
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
    final isHardcore = widget.data['HardcoreMode'] == 1;
    final rarity = widget.data['TrueRatio'] != null
        ? (widget.data['TrueRatio'] / (points > 0 ? points : 1) * 100).toStringAsFixed(1)
        : null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Badge
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.amber, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.amber.withValues(alpha: 0.3),
                blurRadius: 15,
              ),
            ],
          ),
          child: ClipOval(
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
        const SizedBox(height: 16),

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
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
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
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 16),

        // Points and rarity
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
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
            if (rarity != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.purple.withValues(alpha: 0.5)),
                ),
                child: Text(
                  '$rarity% rarity',
                  style: TextStyle(color: Colors.purple[200], fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),

        // Game title
        Text(
          gameTitle,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),

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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Milestone badge
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: milestoneColor.withValues(alpha: 0.2),
            border: Border.all(color: milestoneColor, width: 3),
            boxShadow: [
              BoxShadow(
                color: milestoneColor.withValues(alpha: 0.4),
                blurRadius: 15,
              ),
            ],
          ),
          child: Icon(
            IconData(iconCode, fontFamily: 'MaterialIcons'),
            size: 48,
            color: milestoneColor,
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

        // Earned badge
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
