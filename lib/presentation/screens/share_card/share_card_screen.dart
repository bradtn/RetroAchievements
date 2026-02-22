import 'dart:ui' as ui;
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:image/image.dart' as img;
import '../../providers/auth_provider.dart';
import '../../widgets/premium_gate.dart';
import 'share_card_settings.dart';
import 'share_card_widgets.dart';
import 'card_builders.dart';

export 'share_card_widgets.dart';
export 'card_builders.dart';
export 'share_card_settings.dart';

enum ShareCardType { profile, game, achievement, comparison, milestone, raAward, streak, awardsSummary, goalsSummary, leaderboard }
enum ExportFormat { png, gif }

Uint8List? _encodeGifInIsolate(Map<String, dynamic> data) {
  final frames = data['frames'] as List<Map<String, dynamic>>;
  final delayMs = data['delayMs'] as int;
  final gif = img.GifEncoder();
  for (final frameData in frames) {
    final frame = img.Image.fromBytes(
      width: frameData['width'] as int,
      height: frameData['height'] as int,
      bytes: (frameData['bytes'] as Uint8List).buffer,
      format: img.Format.uint8,
      numChannels: 4,
    );
    gif.addFrame(frame, duration: delayMs ~/ 10);
  }
  return Uint8List.fromList(gif.finish() ?? []);
}

class ShareCardScreen extends ConsumerStatefulWidget {
  final ShareCardType type;
  final Map<String, dynamic> data;

  const ShareCardScreen({super.key, required this.type, required this.data});

  @override
  ConsumerState<ShareCardScreen> createState() => _ShareCardScreenState();
}

class _ShareCardScreenState extends ConsumerState<ShareCardScreen> with TickerProviderStateMixin {
  final GlobalKey _cardKey = GlobalKey();
  bool _isGenerating = false;
  late TabController _tabController;
  late AnimationController _loopController;

  // Settings state
  int _selectedPresetIndex = 0;
  ShareCardSettings _settings = const ShareCardSettings();
  Color _customGradientStart = const Color(0xFF1a1a2e);
  Color _customGradientEnd = const Color(0xFF16213e);
  ExportFormat _exportFormat = ExportFormat.png;
  double _generatingProgress = 0.0;
  bool _isEncoding = false;

  // Animation settings
  SparkleAmount _sparkleAmount = SparkleAmount.few;
  SparkleStyle _sparkleStyle = SparkleStyle.circles;
  SparkleColor _sparkleColor = SparkleColor.white;
  AnimationSpeed _animSpeed = AnimationSpeed.normal;
  bool _breathingEnabled = true;
  bool _glowOrbsEnabled = true;

  // Animation state
  double _animPhase = 0.0;
  List<_Sparkle> _sparkles = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this); // 4 tabs now
    _loopController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat();
    _regenerateSparkles();
    _loopController.addListener(() {
      if (mounted && _exportFormat == ExportFormat.gif) {
        setState(() => _animPhase = _loopController.value);
      }
    });
  }

  void _regenerateSparkles() {
    final count = switch (_sparkleAmount) {
      SparkleAmount.none => 0,
      SparkleAmount.few => 8,
      SparkleAmount.many => 20,
    };
    _sparkles = List.generate(count, (_) => _Sparkle(
      x: _random.nextDouble(),
      y: _random.nextDouble(),
      size: 2 + _random.nextDouble() * 4,
      speed: 0.2 + _random.nextDouble() * 0.4,
      phase: _random.nextDouble(),
      rotationSpeed: _random.nextDouble() * 2 - 1,
    ));
  }

  void _updateAnimSpeed() {
    final duration = switch (_animSpeed) {
      AnimationSpeed.slow => 3000,
      AnimationSpeed.normal => 2000,
      AnimationSpeed.fast => 1200,
    };
    _loopController.duration = Duration(milliseconds: duration);
    if (_loopController.isAnimating) {
      _loopController.repeat();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loopController.dispose();
    super.dispose();
  }

  void _updateSettings(ShareCardSettings s) => setState(() => _settings = s);

  void _selectPreset(int index) {
    final preset = ShareCardSettings.presets[index];
    setState(() {
      _selectedPresetIndex = index;
      _settings = _settings.copyWith(
        gradientStart: preset.isCustom ? _customGradientStart : preset.gradientStart,
        gradientEnd: preset.isCustom ? _customGradientEnd : preset.gradientEnd,
      );
    });
  }

  String? _getGameImageUrl() {
    final icon = widget.data['ImageIcon'] ?? widget.data['GameIcon'] ?? '';
    return icon.isEmpty ? null : icon;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Share Card')),
      body: PremiumGate(
        featureName: 'Share Cards',
        description: 'Create beautiful cards to share your achievements on social media.',
        icon: Icons.share,
        preview: _buildPreview(),
        child: _buildContent(),
      ),
    );
  }

  Widget _buildPreview() {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: null, icon: const Icon(Icons.share), label: const Text('Share Card'))),
      ),
      Expanded(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxCardHeight = constraints.maxHeight - 20;
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxCardHeight, maxWidth: constraints.maxWidth - 32),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: _buildCard(),
                ),
              ),
            );
          },
        ),
      ),
      _buildCustomizationPanel(enabled: false),
    ]);
  }

  Widget _buildContent() {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(children: [
          Container(
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _buildFormatButton(ExportFormat.png, 'PNG'),
              _buildFormatButton(ExportFormat.gif, 'GIF'),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              onPressed: _isGenerating ? null : _shareCard,
              icon: _isGenerating
                  ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white, value: _exportFormat == ExportFormat.gif && !_isEncoding ? _generatingProgress : null))
                  : const Icon(Icons.share),
              label: Text(_isGenerating
                  ? (_exportFormat == ExportFormat.gif
                      ? (_isEncoding ? 'Encoding...' : 'Capturing ${(_generatingProgress * 100).toInt()}%')
                      : 'Creating...')
                  : 'Share ${_exportFormat == ExportFormat.gif ? 'GIF' : 'Image'}'),
            ),
          ),
        ]),
      ),
      Expanded(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Scale down the card to fit in available space with padding for panel
            final maxCardHeight = constraints.maxHeight - 20;
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxCardHeight, maxWidth: constraints.maxWidth - 32),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: RepaintBoundary(key: _cardKey, child: _buildCard()),
                ),
              ),
            );
          },
        ),
      ),
      _buildCustomizationPanel(enabled: true),
    ]);
  }

  Widget _buildFormatButton(ExportFormat format, String label) {
    final sel = _exportFormat == format;
    return GestureDetector(
      onTap: () => setState(() => _exportFormat = format),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(color: sel ? Theme.of(context).colorScheme.primary : Colors.transparent, borderRadius: BorderRadius.circular(8)),
        child: Row(children: [
          if (format == ExportFormat.gif) Icon(Icons.gif_box, size: 16, color: sel ? Colors.white : Colors.white70),
          if (format == ExportFormat.gif) const SizedBox(width: 4),
          Text(label, style: TextStyle(color: sel ? Colors.white : Colors.white70, fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
        ]),
      ),
    );
  }

  Widget _buildCustomizationPanel({required bool enabled}) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TabBar(controller: _tabController, tabs: const [
            Tab(text: 'Colors'),
            Tab(text: 'Style'),
            Tab(text: 'Layout'),
            Tab(text: 'Animate'),
          ]),
          IgnorePointer(
            ignoring: !enabled,
            child: Opacity(
              opacity: enabled ? 1.0 : 0.5,
              child: SizedBox(
                height: 160,
                child: TabBarView(controller: _tabController, children: [_buildColorsTab(), _buildStyleTab(), _buildLayoutTab(), _buildAnimateTab()]),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildColorsTab() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          height: 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: ShareCardSettings.presets.length,
            itemBuilder: (ctx, i) {
              final preset = ShareCardSettings.presets[i];
              final sel = _selectedPresetIndex == i;
              if (preset.isCustom) return _buildCustomColorButton(sel);
              return GestureDetector(
                onTap: () => _selectPreset(i),
                child: Container(
                  width: 50,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [preset.gradientStart, preset.gradientEnd], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(10),
                    border: sel ? Border.all(color: Colors.white, width: 2) : null,
                  ),
                  child: Center(child: Text(preset.name, style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                ),
              );
            },
          ),
        ),
        if (_selectedPresetIndex == ShareCardSettings.presets.length - 1) ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _buildColorPickerButton('Start', _customGradientStart, (c) => setState(() { _customGradientStart = c; _settings = _settings.copyWith(gradientStart: c); }))),
            const SizedBox(width: 12),
            Expanded(child: _buildColorPickerButton('End', _customGradientEnd, (c) => setState(() { _customGradientEnd = c; _settings = _settings.copyWith(gradientEnd: c); }))),
          ]),
        ],
      ]),
    );
  }

  Widget _buildCustomColorButton(bool sel) {
    return GestureDetector(
      onTap: () => _selectPreset(ShareCardSettings.presets.length - 1),
      child: Container(
        width: 50,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [_customGradientStart, _customGradientEnd], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(10),
          border: sel ? Border.all(color: Colors.white, width: 2) : Border.all(color: Colors.white.withValues(alpha: 0.3)),
        ),
        child: const Center(child: Icon(Icons.colorize, color: Colors.white, size: 18)),
      ),
    );
  }

  Widget _buildColorPickerButton(String label, Color color, ValueChanged<Color> onChanged) {
    return GestureDetector(
      onTap: () async {
        Color picked = color;
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Pick a color'),
            content: SingleChildScrollView(child: ColorPicker(color: color, onColorChanged: (c) => picked = c, pickersEnabled: const {ColorPickerType.wheel: true}, enableShadesSelection: true, showColorCode: true, colorCodeHasColor: true)),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')), FilledButton(onPressed: () { onChanged(picked); Navigator.pop(ctx); }, child: const Text('Select'))],
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
        child: Row(children: [
          Container(width: 24, height: 24, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.white.withValues(alpha: 0.3)))),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 12)),
        ]),
      ),
    );
  }

  Widget _buildStyleTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildOptionRow('Pattern', [
          _buildOptionButton('None', _settings.pattern == BackgroundPattern.none, () => _updateSettings(_settings.copyWith(pattern: BackgroundPattern.none))),
          _buildOptionButton('Lines', _settings.pattern == BackgroundPattern.diagonal, () => _updateSettings(_settings.copyWith(pattern: BackgroundPattern.diagonal))),
          _buildOptionButton('Dots', _settings.pattern == BackgroundPattern.dots, () => _updateSettings(_settings.copyWith(pattern: BackgroundPattern.dots))),
          _buildOptionButton('Grid', _settings.pattern == BackgroundPattern.grid, () => _updateSettings(_settings.copyWith(pattern: BackgroundPattern.grid))),
          if (_getGameImageUrl() != null) _buildOptionButton('Game', _settings.pattern == BackgroundPattern.gameBlur, () => _updateSettings(_settings.copyWith(pattern: BackgroundPattern.gameBlur))),
        ]),
        const SizedBox(height: 8),
        _buildOptionRow('Font', [
          _buildOptionButton('Modern', _settings.fontStyle == CardFontStyle.modern, () => _updateSettings(_settings.copyWith(fontStyle: CardFontStyle.modern))),
          _buildOptionButton('Pixel', _settings.fontStyle == CardFontStyle.pixel, () => _updateSettings(_settings.copyWith(fontStyle: CardFontStyle.pixel))),
        ]),
        const SizedBox(height: 8),
        _buildOptionRow('Border', [
          _buildOptionButton('None', _settings.borderStyle == CardBorderStyle.none, () => _updateSettings(_settings.copyWith(borderStyle: CardBorderStyle.none))),
          _buildOptionButton('Thin', _settings.borderStyle == CardBorderStyle.thin, () => _updateSettings(_settings.copyWith(borderStyle: CardBorderStyle.thin))),
          _buildOptionButton('Thick', _settings.borderStyle == CardBorderStyle.thick, () => _updateSettings(_settings.copyWith(borderStyle: CardBorderStyle.thick))),
          _buildOptionButton('Glow', _settings.borderStyle == CardBorderStyle.glow, () => _updateSettings(_settings.copyWith(borderStyle: CardBorderStyle.glow))),
        ]),
      ]),
    );
  }

  Widget _buildLayoutTab() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildOptionRow('Layout', [
          _buildOptionButton('Detailed', _settings.layout == CardLayout.detailed, () => _updateSettings(_settings.copyWith(layout: CardLayout.detailed))),
          _buildOptionButton('Compact', _settings.layout == CardLayout.compact, () => _updateSettings(_settings.copyWith(layout: CardLayout.compact))),
        ]),
        const SizedBox(height: 8),
        _buildOptionRow('Avatar', [
          _buildOptionButton('Circle', _settings.avatarFrame == AvatarFrame.circle, () => _updateSettings(_settings.copyWith(avatarFrame: AvatarFrame.circle))),
          _buildOptionButton('Rounded', _settings.avatarFrame == AvatarFrame.roundedSquare, () => _updateSettings(_settings.copyWith(avatarFrame: AvatarFrame.roundedSquare))),
          _buildOptionButton('Square', _settings.avatarFrame == AvatarFrame.square, () => _updateSettings(_settings.copyWith(avatarFrame: AvatarFrame.square))),
        ]),
      ]),
    );
  }

  Widget _buildAnimateTab() {
    final isGif = _exportFormat == ExportFormat.gif;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Opacity(
        opacity: isGif ? 1.0 : 0.4,
        child: IgnorePointer(
          ignoring: !isGif,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left column: Amount & Speed
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildCompactOptionRow('Amount', [
                      _buildSmallButton('None', _sparkleAmount == SparkleAmount.none, () { setState(() => _sparkleAmount = SparkleAmount.none); _regenerateSparkles(); }),
                      _buildSmallButton('Few', _sparkleAmount == SparkleAmount.few, () { setState(() => _sparkleAmount = SparkleAmount.few); _regenerateSparkles(); }),
                      _buildSmallButton('Many', _sparkleAmount == SparkleAmount.many, () { setState(() => _sparkleAmount = SparkleAmount.many); _regenerateSparkles(); }),
                    ]),
                    const SizedBox(height: 6),
                    _buildCompactOptionRow('Speed', [
                      _buildSmallButton('Slow', _animSpeed == AnimationSpeed.slow, () { setState(() => _animSpeed = AnimationSpeed.slow); _updateAnimSpeed(); }),
                      _buildSmallButton('Med', _animSpeed == AnimationSpeed.normal, () { setState(() => _animSpeed = AnimationSpeed.normal); _updateAnimSpeed(); }),
                      _buildSmallButton('Fast', _animSpeed == AnimationSpeed.fast, () { setState(() => _animSpeed = AnimationSpeed.fast); _updateAnimSpeed(); }),
                    ]),
                    const SizedBox(height: 6),
                    _buildCompactOptionRow('Color', [
                      _buildSmallButton('White', _sparkleColor == SparkleColor.white, () => setState(() => _sparkleColor = SparkleColor.white)),
                      _buildSmallButton('Gold', _sparkleColor == SparkleColor.gold, () => setState(() => _sparkleColor = SparkleColor.gold)),
                      _buildSmallButton('RGB', _sparkleColor == SparkleColor.rainbow, () => setState(() => _sparkleColor = SparkleColor.rainbow)),
                    ]),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Right column: Shapes grid
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Shape', style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.7))),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 114,
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        _buildShapeButton('●', SparkleStyle.circles),
                        _buildShapeButton('✦', SparkleStyle.stars),
                        _buildShapeButton('♥', SparkleStyle.hearts),
                        _buildShapeButton('◆', SparkleStyle.diamonds),
                        _buildShapeButton('▲□', SparkleStyle.playstation),
                        _buildShapeButton('AB', SparkleStyle.xbox),
                        _buildShapeButton('↑↓', SparkleStyle.dpad),
                        _buildShapeButton('🍄', SparkleStyle.retro),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactOptionRow(String label, List<Widget> options) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.7))),
        const SizedBox(height: 2),
        Row(mainAxisSize: MainAxisSize.min, children: options),
      ],
    );
  }

  Widget _buildSmallButton(String label, bool sel, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(color: sel ? Theme.of(context).colorScheme.primary : Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
        child: Text(label, style: TextStyle(fontSize: 10, fontWeight: sel ? FontWeight.bold : FontWeight.normal, color: sel ? Colors.white : Colors.white.withValues(alpha: 0.8))),
      ),
    );
  }

  Widget _buildShapeButton(String symbol, SparkleStyle style) {
    final sel = _sparkleStyle == style;
    return GestureDetector(
      onTap: () => setState(() => _sparkleStyle = style),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(color: sel ? Theme.of(context).colorScheme.primary : Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
        child: Center(child: Text(symbol, style: TextStyle(fontSize: 14, color: sel ? Colors.white : Colors.white.withValues(alpha: 0.8)))),
      ),
    );
  }

  Widget _buildOptionRow(String label, List<Widget> options) {
    return Row(children: [
      SizedBox(width: 60, child: Text(label, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7)))),
      Expanded(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: options))),
    ]);
  }

  Widget _buildOptionButton(String label, bool sel, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(color: sel ? Theme.of(context).colorScheme.primary : Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: sel ? FontWeight.bold : FontWeight.normal, color: sel ? Colors.white : Colors.white.withValues(alpha: 0.8))),
      ),
    );
  }

  Widget _buildCard() {
    final isGif = _exportFormat == ExportFormat.gif;
    return Container(
      width: 350,
      decoration: getCardBorderDecoration(borderStyle: _settings.borderStyle, gradientColors: [_settings.gradientStart, _settings.gradientEnd]),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(children: [
          buildPatternOverlay(_settings.pattern, gameImageUrl: _getGameImageUrl()),
          if (isGif && _sparkleAmount != SparkleAmount.none) ..._buildSparkles(),
          if (isGif && _settings.borderStyle == CardBorderStyle.glow && _glowOrbsEnabled)
            Positioned.fill(child: CustomPaint(painter: _GlowBorderPainter(_animPhase, _settings.gradientStart))),
          Padding(
            padding: EdgeInsets.all(_settings.layout == CardLayout.compact ? 16 : 24),
            child: isGif && _breathingEnabled
                ? Transform.scale(scale: 1.0 + 0.015 * math.sin(_animPhase * 2 * math.pi), child: _buildCardContent())
                : _buildCardContent(),
          ),
        ]),
      ),
    );
  }

  List<Widget> _buildSparkles() {
    return _sparkles.asMap().entries.map((entry) {
      final i = entry.key;
      final s = entry.value;
      final adjustedY = (s.y - (_animPhase * s.speed)) % 1.0;
      final twinkle = (0.3 + 0.7 * math.sin((s.phase + _animPhase * 3) * math.pi)).clamp(0.0, 1.0);
      final rotation = _animPhase * s.rotationSpeed * 2 * math.pi;

      Color color;
      switch (_sparkleColor) {
        case SparkleColor.white: color = Colors.white; break;
        case SparkleColor.gold: color = Colors.amber[300]!; break;
        case SparkleColor.rainbow: color = HSLColor.fromAHSL(1, (i / _sparkles.length) * 360, 0.8, 0.7).toColor(); break;
        case SparkleColor.gradient: color = Color.lerp(_settings.gradientStart, _settings.gradientEnd, i / _sparkles.length)!.withValues(alpha: 1); break;
      }

      Widget sparkleWidget;
      switch (_sparkleStyle) {
        case SparkleStyle.circles:
          sparkleWidget = Container(
            width: s.size,
            height: s.size,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color, boxShadow: [BoxShadow(color: color.withValues(alpha: 0.8), blurRadius: s.size * 2, spreadRadius: 1)]),
          );
          break;
        case SparkleStyle.stars:
          sparkleWidget = Transform.rotate(angle: rotation, child: CustomPaint(size: Size(s.size * 2, s.size * 2), painter: _StarPainter(color)));
          break;
        case SparkleStyle.hearts:
          sparkleWidget = Text('♥', style: TextStyle(fontSize: s.size * 1.5, color: color, shadows: [Shadow(color: color.withValues(alpha: 0.8), blurRadius: s.size * 2)]));
          break;
        case SparkleStyle.diamonds:
          sparkleWidget = Transform.rotate(angle: rotation * 0.5, child: Container(
            width: s.size * 1.2,
            height: s.size * 1.2,
            decoration: BoxDecoration(color: color, shape: BoxShape.rectangle, boxShadow: [BoxShadow(color: color.withValues(alpha: 0.8), blurRadius: s.size * 2)]),
            transform: Matrix4.rotationZ(math.pi / 4),
          ));
          break;
        case SparkleStyle.sparkles:
          sparkleWidget = Transform.rotate(angle: rotation, child: Text('✨', style: TextStyle(fontSize: s.size * 1.8, shadows: [Shadow(color: color.withValues(alpha: 0.8), blurRadius: s.size * 2)])));
          break;
        case SparkleStyle.plus:
          sparkleWidget = Transform.rotate(angle: rotation * 0.3, child: CustomPaint(size: Size(s.size * 2, s.size * 2), painter: _PlusPainter(color)));
          break;
        case SparkleStyle.playstation:
          // Cycle through PS button shapes based on index
          final psShapes = ['△', '□', '✕', '○'];
          final psColors = [Colors.green, Colors.pink, Colors.blue, Colors.red];
          final shapeIndex = i % 4;
          final psColor = psColors[shapeIndex];
          sparkleWidget = Transform.rotate(
            angle: rotation * 0.2,
            child: Text(
              psShapes[shapeIndex],
              style: TextStyle(
                fontSize: s.size * 2,
                color: psColor,
                fontWeight: FontWeight.bold,
                shadows: [Shadow(color: psColor.withValues(alpha: 0.8), blurRadius: s.size * 2)],
              ),
            ),
          );
          break;
        case SparkleStyle.xbox:
          // Xbox buttons A B X Y with their colors
          final xboxShapes = ['A', 'B', 'X', 'Y'];
          final xboxColors = [Colors.green, Colors.red, Colors.blue, Colors.yellow];
          final xboxIndex = i % 4;
          final xboxColor = xboxColors[xboxIndex];
          sparkleWidget = Transform.rotate(
            angle: rotation * 0.15,
            child: Container(
              width: s.size * 2.5,
              height: s.size * 2.5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: xboxColor,
                boxShadow: [BoxShadow(color: xboxColor.withValues(alpha: 0.8), blurRadius: s.size * 2)],
              ),
              child: Center(
                child: Text(
                  xboxShapes[xboxIndex],
                  style: TextStyle(
                    fontSize: s.size * 1.3,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
          break;
        case SparkleStyle.dpad:
          // D-pad arrows
          final dpadShapes = ['↑', '↓', '←', '→'];
          final dpadIndex = i % 4;
          sparkleWidget = Text(
            dpadShapes[dpadIndex],
            style: TextStyle(
              fontSize: s.size * 2.2,
              color: color,
              fontWeight: FontWeight.bold,
              shadows: [Shadow(color: color.withValues(alpha: 0.8), blurRadius: s.size * 2)],
            ),
          );
          break;
        case SparkleStyle.retro:
          // Retro gaming items - Mario style
          final retroShapes = ['🍄', '⭐', '🪙', '❤️'];
          final retroIndex = i % 4;
          sparkleWidget = Transform.rotate(
            angle: rotation * 0.1,
            child: Text(
              retroShapes[retroIndex],
              style: TextStyle(
                fontSize: s.size * 1.8,
                shadows: [Shadow(color: Colors.white.withValues(alpha: 0.5), blurRadius: s.size * 2)],
              ),
            ),
          );
          break;
      }

      return Positioned(
        left: s.x * 340,
        top: adjustedY * 380,
        child: Opacity(opacity: twinkle, child: sparkleWidget),
      );
    }).toList();
  }

  Widget _buildCardContent() {
    final username = ref.read(authProvider).username ?? 'Player';
    return switch (widget.type) {
      ShareCardType.profile => ProfileCard(data: widget.data, settings: _settings),
      ShareCardType.game => GameCard(data: widget.data, username: username, settings: _settings),
      ShareCardType.achievement => AchievementCard(data: widget.data, settings: _settings),
      ShareCardType.comparison => ComparisonCard(data: widget.data, settings: _settings),
      ShareCardType.milestone => MilestoneCard(data: widget.data, settings: _settings),
      ShareCardType.raAward => RAAwardCard(data: widget.data, settings: _settings),
      ShareCardType.streak => StreakCard(data: widget.data, settings: _settings),
      ShareCardType.awardsSummary => AwardsSummaryCard(data: widget.data, settings: _settings),
      ShareCardType.goalsSummary => GoalsSummaryCard(data: widget.data, settings: _settings),
      ShareCardType.leaderboard => LeaderboardCard(data: widget.data, settings: _settings),
    };
  }

  Future<void> _shareCard() async {
    setState(() { _isGenerating = true; _generatingProgress = 0.0; });
    try {
      final tempDir = await getTemporaryDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      if (_exportFormat == ExportFormat.gif) {
        await _shareAsGif(tempDir, ts);
      } else {
        await _shareAsPng(tempDir, ts);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() { _isGenerating = false; _isEncoding = false; });
    }
  }

  Future<void> _shareAsPng(Directory dir, int ts) async {
    final boundary = _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) throw Exception('Could not capture');
    final image = await boundary.toImage(pixelRatio: 3.0);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw Exception('Could not convert');
    final file = File('${dir.path}/retrotracker_$ts.png');
    await file.writeAsBytes(data.buffer.asUint8List());
    await Share.shareXFiles([XFile(file.path)], text: _getShareText());
  }

  Future<void> _shareAsGif(Directory dir, int ts) async {
    _loopController.stop();
    const frameCount = 16;
    final delayMs = switch (_animSpeed) { AnimationSpeed.slow => 100, AnimationSpeed.normal => 70, AnimationSpeed.fast => 50 };
    final frames = <Map<String, dynamic>>[];

    try {
      for (int i = 0; i < frameCount; i++) {
        setState(() { _animPhase = i / frameCount; _generatingProgress = (i / frameCount) * 0.5; });
        await Future.delayed(const Duration(milliseconds: 40));
        final boundary = _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
        if (boundary == null) continue;
        final image = await boundary.toImage(pixelRatio: 1.5);
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        if (data == null) continue;
        frames.add({'width': image.width, 'height': image.height, 'bytes': Uint8List.fromList(data.buffer.asUint8List())});
        setState(() => _generatingProgress = 0.5 + (i / frameCount) * 0.2);
      }
      if (frames.isEmpty) throw Exception('No frames');
      setState(() { _generatingProgress = 0.75; _isEncoding = true; });
      final gifBytes = await compute(_encodeGifInIsolate, {'frames': frames, 'delayMs': delayMs});
      if (gifBytes == null || gifBytes.isEmpty) throw Exception('Encode failed');
      setState(() { _generatingProgress = 0.95; _isEncoding = false; });
      final file = File('${dir.path}/retrotracker_$ts.gif');
      await file.writeAsBytes(gifBytes);
      setState(() => _generatingProgress = 1.0);
      await Share.shareXFiles([XFile(file.path)], text: _getShareText());
    } finally {
      _loopController.repeat();
    }
  }

  String _getShareText() {
    return switch (widget.type) {
      ShareCardType.profile => 'Check out my RetroAchievements profile! ${widget.data['TotalPoints'] ?? 0} points #RetroAchievements',
      ShareCardType.game => 'Playing ${widget.data['Title'] ?? 'Game'} - ${widget.data['NumAwardedToUser'] ?? widget.data['NumAchieved'] ?? 0}/${widget.data['NumAchievements'] ?? widget.data['NumPossibleAchievements'] ?? 0} achievements! #RetroAchievements',
      ShareCardType.achievement => 'Just unlocked "${widget.data['Title']}" in ${widget.data['GameTitle']}! #RetroAchievements',
      ShareCardType.comparison => 'Check out my comparison vs ${(widget.data['otherProfile'] as Map?)?['User'] ?? 'Opponent'}! #RetroAchievements',
      ShareCardType.milestone => '${widget.data['username'] ?? 'Player'} completed "${widget.data['title']}"! #RetroAchievements',
      ShareCardType.raAward => '${widget.data['username']} earned ${widget.data['awardType']} on ${widget.data['title']}! #RetroAchievements',
      ShareCardType.streak => '${widget.data['username']} is on a ${widget.data['currentStreak']} day streak! #RetroAchievements',
      ShareCardType.awardsSummary => '${widget.data['username']} has ${widget.data['totalAwards']} RetroAchievements awards! #RetroAchievements',
      ShareCardType.goalsSummary => '${widget.data['username']} completed ${widget.data['completed']}/${widget.data['total']} RetroTrack goals! #RetroAchievements',
      ShareCardType.leaderboard => '${widget.data['username']} ranked #${widget.data['rank']} on "${widget.data['leaderboardTitle']}" in ${widget.data['gameTitle']}! #RetroAchievements',
    };
  }
}

class _Sparkle {
  final double x, y, size, speed, phase, rotationSpeed;
  _Sparkle({required this.x, required this.y, required this.size, required this.speed, required this.phase, required this.rotationSpeed});
}

class _StarPainter extends CustomPainter {
  final Color color;
  _StarPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    final path = Path();
    final cx = size.width / 2, cy = size.height / 2;
    final outer = size.width / 2, inner = size.width / 5;
    for (int i = 0; i < 4; i++) {
      final angle = (i * math.pi / 2) - math.pi / 2;
      final nextAngle = angle + math.pi / 4;
      if (i == 0) {
        path.moveTo(cx + outer * math.cos(angle), cy + outer * math.sin(angle));
      } else {
        path.lineTo(cx + outer * math.cos(angle), cy + outer * math.sin(angle));
      }
      path.lineTo(cx + inner * math.cos(nextAngle), cy + inner * math.sin(nextAngle));
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _StarPainter old) => old.color != color;
}

class _PlusPainter extends CustomPainter {
  final Color color;
  _PlusPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    final thickness = size.width / 4;
    final cx = size.width / 2, cy = size.height / 2;
    // Horizontal bar
    canvas.drawRect(Rect.fromCenter(center: Offset(cx, cy), width: size.width, height: thickness), paint);
    // Vertical bar
    canvas.drawRect(Rect.fromCenter(center: Offset(cx, cy), width: thickness, height: size.height), paint);
  }

  @override
  bool shouldRepaint(covariant _PlusPainter old) => old.color != color;
}

class _GlowBorderPainter extends CustomPainter {
  final double phase;
  final Color baseColor;
  _GlowBorderPainter(this.phase, this.baseColor);

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < 3; i++) {
      final angle = (phase + i / 3) * 2 * math.pi;
      final x = size.width / 2 + math.cos(angle) * size.width * 0.4;
      final y = size.height / 2 + math.sin(angle) * size.height * 0.35;
      final paint = Paint()..color = baseColor.withValues(alpha: 0.5)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 25);
      canvas.drawCircle(Offset(x, y), 25, paint);
    }
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25 + 0.15 * math.sin(phase * 2 * math.pi))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height), const Radius.circular(20)), borderPaint);
  }

  @override
  bool shouldRepaint(covariant _GlowBorderPainter old) => old.phase != phase;
}
