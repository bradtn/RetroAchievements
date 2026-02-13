import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'dart:io';
import '../../providers/auth_provider.dart';
import '../../widgets/premium_gate.dart';
import 'share_card_settings.dart';
import 'share_card_widgets.dart';
import 'card_builders.dart';

export 'share_card_widgets.dart';
export 'card_builders.dart';
export 'share_card_settings.dart';

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

class _ShareCardScreenState extends ConsumerState<ShareCardScreen> with SingleTickerProviderStateMixin {
  final GlobalKey _cardKey = GlobalKey();
  bool _isGenerating = false;
  late TabController _tabController;

  // Settings state
  int _selectedPresetIndex = 0;
  ShareCardSettings _settings = const ShareCardSettings();
  Color _customGradientStart = const Color(0xFF1a1a2e);
  Color _customGradientEnd = const Color(0xFF16213e);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _updateSettings(ShareCardSettings newSettings) {
    setState(() {
      _settings = newSettings;
    });
  }

  void _selectPreset(int index) {
    final preset = ShareCardSettings.presets[index];
    setState(() {
      _selectedPresetIndex = index;
      if (!preset.isCustom) {
        _settings = _settings.copyWith(
          gradientStart: preset.gradientStart,
          gradientEnd: preset.gradientEnd,
        );
      } else {
        _settings = _settings.copyWith(
          gradientStart: _customGradientStart,
          gradientEnd: _customGradientEnd,
        );
      }
    });
  }

  String? _getGameImageUrl() {
    final imageIcon = widget.data['ImageIcon'] ?? widget.data['GameIcon'] ?? '';
    if (imageIcon.isEmpty) return null;
    return imageIcon;
  }

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
        preview: _buildPreview(context),
        child: _buildContent(context),
      ),
    );
  }

  Widget _buildPreview(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: null,
              icon: const Icon(Icons.share),
              label: const Text('Share Card'),
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: _buildCard(),
            ),
          ),
        ),
        _buildCustomizationPanel(enabled: false),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    return Column(
      children: [
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
        _buildCustomizationPanel(enabled: true),
      ],
    );
  }

  Widget _buildCustomizationPanel({required bool enabled}) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Colors'),
                Tab(text: 'Style'),
                Tab(text: 'Layout'),
              ],
            ),
            IgnorePointer(
              ignoring: !enabled,
              child: Opacity(
                opacity: enabled ? 1.0 : 0.5,
                child: SizedBox(
                  height: 140,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildColorsTab(),
                      _buildStyleTab(),
                      _buildLayoutTab(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorsTab() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: ShareCardSettings.presets.length,
              itemBuilder: (ctx, i) {
                final preset = ShareCardSettings.presets[i];
                final isSelected = _selectedPresetIndex == i;

                if (preset.isCustom) {
                  return _buildCustomColorButton(isSelected);
                }

                return GestureDetector(
                  onTap: () => _selectPreset(i),
                  child: Container(
                    width: 50,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [preset.gradientStart, preset.gradientEnd],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: isSelected
                          ? Border.all(color: Colors.white, width: 2)
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        preset.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_selectedPresetIndex == ShareCardSettings.presets.length - 1) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildColorPickerButton(
                    'Start',
                    _customGradientStart,
                    (color) {
                      setState(() {
                        _customGradientStart = color;
                        _settings = _settings.copyWith(gradientStart: color);
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildColorPickerButton(
                    'End',
                    _customGradientEnd,
                    (color) {
                      setState(() {
                        _customGradientEnd = color;
                        _settings = _settings.copyWith(gradientEnd: color);
                      });
                    },
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCustomColorButton(bool isSelected) {
    return GestureDetector(
      onTap: () => _selectPreset(ShareCardSettings.presets.length - 1),
      child: Container(
        width: 50,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_customGradientStart, _customGradientEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(10),
          border: isSelected
              ? Border.all(color: Colors.white, width: 2)
              : Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
        ),
        child: const Center(
          child: Icon(Icons.colorize, color: Colors.white, size: 18),
        ),
      ),
    );
  }

  Widget _buildColorPickerButton(String label, Color color, ValueChanged<Color> onColorChanged) {
    return GestureDetector(
      onTap: () => _showColorPicker(color, onColorChanged),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
              ),
            ),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Future<void> _showColorPicker(Color currentColor, ValueChanged<Color> onColorChanged) async {
    Color pickedColor = currentColor;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pick a color'),
        content: SingleChildScrollView(
          child: ColorPicker(
            color: currentColor,
            onColorChanged: (color) => pickedColor = color,
            pickersEnabled: const {
              ColorPickerType.wheel: true,
              ColorPickerType.accent: false,
              ColorPickerType.primary: false,
            },
            enableShadesSelection: true,
            showColorCode: true,
            colorCodeHasColor: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              onColorChanged(pickedColor);
              Navigator.pop(context);
            },
            child: const Text('Select'),
          ),
        ],
      ),
    );
  }

  Widget _buildStyleTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildOptionRow('Pattern', [
            _buildOptionButton('None', _settings.pattern == BackgroundPattern.none,
                () => _updateSettings(_settings.copyWith(pattern: BackgroundPattern.none))),
            _buildOptionButton('Lines', _settings.pattern == BackgroundPattern.diagonal,
                () => _updateSettings(_settings.copyWith(pattern: BackgroundPattern.diagonal))),
            _buildOptionButton('Dots', _settings.pattern == BackgroundPattern.dots,
                () => _updateSettings(_settings.copyWith(pattern: BackgroundPattern.dots))),
            _buildOptionButton('Grid', _settings.pattern == BackgroundPattern.grid,
                () => _updateSettings(_settings.copyWith(pattern: BackgroundPattern.grid))),
            if (_getGameImageUrl() != null)
              _buildOptionButton('Game', _settings.pattern == BackgroundPattern.gameBlur,
                  () => _updateSettings(_settings.copyWith(pattern: BackgroundPattern.gameBlur))),
          ]),
          const SizedBox(height: 8),
          _buildOptionRow('Font', [
            _buildOptionButton('Modern', _settings.fontStyle == CardFontStyle.modern,
                () => _updateSettings(_settings.copyWith(fontStyle: CardFontStyle.modern))),
            _buildOptionButton('Pixel', _settings.fontStyle == CardFontStyle.pixel,
                () => _updateSettings(_settings.copyWith(fontStyle: CardFontStyle.pixel))),
          ]),
          const SizedBox(height: 8),
          _buildOptionRow('Border', [
            _buildOptionButton('None', _settings.borderStyle == CardBorderStyle.none,
                () => _updateSettings(_settings.copyWith(borderStyle: CardBorderStyle.none))),
            _buildOptionButton('Thin', _settings.borderStyle == CardBorderStyle.thin,
                () => _updateSettings(_settings.copyWith(borderStyle: CardBorderStyle.thin))),
            _buildOptionButton('Thick', _settings.borderStyle == CardBorderStyle.thick,
                () => _updateSettings(_settings.copyWith(borderStyle: CardBorderStyle.thick))),
            _buildOptionButton('Glow', _settings.borderStyle == CardBorderStyle.glow,
                () => _updateSettings(_settings.copyWith(borderStyle: CardBorderStyle.glow))),
          ]),
        ],
      ),
    );
  }

  Widget _buildLayoutTab() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildOptionRow('Layout', [
            _buildOptionButton('Detailed', _settings.layout == CardLayout.detailed,
                () => _updateSettings(_settings.copyWith(layout: CardLayout.detailed))),
            _buildOptionButton('Compact', _settings.layout == CardLayout.compact,
                () => _updateSettings(_settings.copyWith(layout: CardLayout.compact))),
          ]),
          const SizedBox(height: 8),
          _buildOptionRow('Avatar', [
            _buildOptionButton('Circle', _settings.avatarFrame == AvatarFrame.circle,
                () => _updateSettings(_settings.copyWith(avatarFrame: AvatarFrame.circle))),
            _buildOptionButton('Rounded', _settings.avatarFrame == AvatarFrame.roundedSquare,
                () => _updateSettings(_settings.copyWith(avatarFrame: AvatarFrame.roundedSquare))),
            _buildOptionButton('Square', _settings.avatarFrame == AvatarFrame.square,
                () => _updateSettings(_settings.copyWith(avatarFrame: AvatarFrame.square))),
          ]),
        ],
      ),
    );
  }

  Widget _buildOptionRow(String label, List<Widget> options) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: options),
          ),
        ),
      ],
    );
  }

  Widget _buildOptionButton(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.8),
          ),
        ),
      ),
    );
  }

  Widget _buildCard() {
    final gradientColors = [_settings.gradientStart, _settings.gradientEnd];

    return Container(
      width: 350,
      decoration: getCardBorderDecoration(
        borderStyle: _settings.borderStyle,
        gradientColors: gradientColors,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Pattern overlay
            buildPatternOverlay(_settings.pattern, gameImageUrl: _getGameImageUrl()),
            // Content
            Padding(
              padding: EdgeInsets.all(_settings.layout == CardLayout.compact ? 16 : 24),
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
      ShareCardType.profile => ProfileCard(data: widget.data, settings: _settings),
      ShareCardType.game => GameCard(data: widget.data, username: username, settings: _settings),
      ShareCardType.achievement => AchievementCard(data: widget.data, settings: _settings),
      ShareCardType.comparison => ComparisonCard(data: widget.data, settings: _settings),
      ShareCardType.milestone => MilestoneCard(data: widget.data, settings: _settings),
      ShareCardType.raAward => RAAwardCard(data: widget.data, settings: _settings),
      ShareCardType.streak => StreakCard(data: widget.data, settings: _settings),
    };
  }

  Future<void> _shareCard() async {
    setState(() => _isGenerating = true);

    try {
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

      final tempDir = await getTemporaryDirectory();
      final fileName = 'retrotracker_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(bytes);

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
        return 'Check out my RetroAchievements profile! $points points #RetroAchievements #RetroTrack';
      case ShareCardType.game:
        final title = widget.data['Title'] ?? 'Game';
        final earned = widget.data['NumAwardedToUser'] ?? widget.data['NumAchieved'] ?? 0;
        final total = widget.data['NumAchievements'] ?? widget.data['NumPossibleAchievements'] ?? 0;
        return 'Playing $title - $earned/$total achievements! #RetroAchievements #RetroTrack';
      case ShareCardType.achievement:
        final title = widget.data['Title'] ?? 'Achievement';
        final gameTitle = widget.data['GameTitle'] ?? '';
        return 'Just unlocked "$title" in $gameTitle! #RetroAchievements #RetroTrack';
      case ShareCardType.comparison:
        final otherProfile = widget.data['otherProfile'] as Map<String, dynamic>? ?? {};
        final otherName = otherProfile['User'] ?? 'Opponent';
        return 'Check out my comparison vs $otherName on RetroAchievements! #RetroAchievements #RetroTrack';
      case ShareCardType.milestone:
        final goalTitle = widget.data['title'] ?? 'Goal';
        final username = widget.data['username'] ?? 'Player';
        return '$username completed the "$goalTitle" goal! #RetroAchievements #RetroTrack';
      case ShareCardType.raAward:
        final awardTitle = widget.data['title'] ?? 'Game';
        final awardType = widget.data['awardType'] ?? 'Award';
        final username = widget.data['username'] ?? 'Player';
        return '$username earned $awardType on $awardTitle! #RetroAchievements #RetroTrack';
      case ShareCardType.streak:
        final currentStreak = widget.data['currentStreak'] ?? 0;
        final username = widget.data['username'] ?? 'Player';
        return '$username is on a $currentStreak day streak! #RetroAchievements #RetroTrack';
    }
  }
}
