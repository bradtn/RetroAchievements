import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../providers/auth_provider.dart';
import '../../widgets/premium_gate.dart';
import 'share_card_widgets.dart';
import 'card_builders.dart';

export 'share_card_widgets.dart';
export 'card_builders.dart';

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

  final List<CardStyle> _styles = [
    CardStyle('Classic', [const Color(0xFF1a1a2e), const Color(0xFF16213e)]),
    CardStyle('Retro', [const Color(0xFF2d132c), const Color(0xFF801336)]),
    CardStyle('Neon', [const Color(0xFF0f0c29), const Color(0xFF302b63)]),
    CardStyle('Forest', [const Color(0xFF134e5e), const Color(0xFF71b280)]),
    CardStyle('Sunset', [const Color(0xFFff6b6b), const Color(0xFFfeca57)]),
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
              itemBuilder: (ctx, i) => StyleButton(
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
                painter: PatternPainter(),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(24),
              child: _buildCardContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardContent() {
    final authState = ref.read(authProvider);
    final username = authState.username ?? 'Player';

    return switch (widget.type) {
      ShareCardType.profile => ProfileCard(data: widget.data),
      ShareCardType.game => GameCard(data: widget.data, username: username),
      ShareCardType.achievement => AchievementCard(data: widget.data),
      ShareCardType.comparison => ComparisonCard(data: widget.data),
      ShareCardType.milestone => MilestoneCard(data: widget.data),
      ShareCardType.raAward => RAAwardCard(data: widget.data),
      ShareCardType.streak => StreakCard(data: widget.data),
    };
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
        final points = widget.data['TotalPoints'] ?? 0;
        return 'Check out my RetroAchievements profile! $points points #RetroAchievements #RetroTracker';
      case ShareCardType.game:
        final title = widget.data['Title'] ?? 'Game';
        final earned = widget.data['NumAwardedToUser'] ?? widget.data['NumAchieved'] ?? 0;
        final total = widget.data['NumAchievements'] ?? widget.data['NumPossibleAchievements'] ?? 0;
        return 'Playing $title - $earned/$total achievements! #RetroAchievements #RetroTracker';
      case ShareCardType.achievement:
        final title = widget.data['Title'] ?? 'Achievement';
        final gameTitle = widget.data['GameTitle'] ?? '';
        return 'Just unlocked "$title" in $gameTitle! #RetroAchievements #RetroTracker';
      case ShareCardType.comparison:
        final otherProfile = widget.data['otherProfile'] as Map<String, dynamic>? ?? {};
        final otherName = otherProfile['User'] ?? 'Opponent';
        return 'Check out my comparison vs $otherName on RetroAchievements! #RetroAchievements #RetroTracker';
      case ShareCardType.milestone:
        final goalTitle = widget.data['title'] ?? 'Goal';
        final username = widget.data['username'] ?? 'Player';
        return '$username completed the "$goalTitle" goal! #RetroAchievements #RetroTracker';
      case ShareCardType.raAward:
        final awardTitle = widget.data['title'] ?? 'Game';
        final awardType = widget.data['awardType'] ?? 'Award';
        final username = widget.data['username'] ?? 'Player';
        return '$username earned $awardType on $awardTitle! #RetroAchievements #RetroTracker';
      case ShareCardType.streak:
        final currentStreak = widget.data['currentStreak'] ?? 0;
        final username = widget.data['username'] ?? 'Player';
        return '$username is on a $currentStreak day streak! #RetroAchievements #RetroTracker';
    }
  }
}
