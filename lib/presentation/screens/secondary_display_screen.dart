import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// App for the secondary display - shows achievements list
/// This is a standalone Flutter app that runs on the secondary display
/// but communicates with the main app for a unified experience
///
/// NOTE: Uses Unicode characters instead of Material Icons because
/// the secondary Flutter engine doesn't have access to icon fonts
class SecondaryDisplayApp extends StatelessWidget {
  const SecondaryDisplayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RetroTrack - Achievements',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardTheme: const CardThemeData(
          color: Color(0xFF1e1e2e),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
        ),
      ),
      home: const SecondaryDisplayScreen(),
    );
  }
}

/// Filter options matching main screen
enum AchievementFilter { all, earned, unearned }

/// Sort options matching main screen
enum AchievementSort { normal, points, rarity }

/// The main screen for the secondary display
class SecondaryDisplayScreen extends StatefulWidget {
  const SecondaryDisplayScreen({super.key});

  @override
  State<SecondaryDisplayScreen> createState() => _SecondaryDisplayScreenState();
}

class _SecondaryDisplayScreenState extends State<SecondaryDisplayScreen> {
  static const _channel = MethodChannel('com.retrotracker.retrotracker/secondary_display');

  Map<String, dynamic>? _gameData;
  List<Map<String, dynamic>> _achievements = [];
  Map<String, dynamic>? _displayInfo;

  // Filter/sort state - synced with main screen
  AchievementFilter _filter = AchievementFilter.all;
  AchievementSort _sort = AchievementSort.normal;
  bool _showMissable = false;
  int _numDistinctPlayers = 0;

  @override
  void initState() {
    super.initState();
    _setupMethodChannel();
  }

  void _setupMethodChannel() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'updateGameData':
          final data = Map<String, dynamic>.from(call.arguments as Map);
          setState(() {
            _gameData = data;
            _achievements = _parseAchievements(data['achievements']);
            _numDistinctPlayers = data['numDistinctPlayers'] ?? 0;
            // Sync filter/sort state from main if provided
            if (data['filter'] != null) {
              _filter = AchievementFilter.values[data['filter'] as int];
            }
            if (data['sort'] != null) {
              _sort = AchievementSort.values[data['sort'] as int];
            }
            if (data['showMissable'] != null) {
              _showMissable = data['showMissable'] as bool;
            }
          });
          return true;
        case 'displayInfo':
          setState(() {
            _displayInfo = Map<String, dynamic>.from(call.arguments as Map);
          });
          return true;
        case 'syncFilterState':
          // Main screen is syncing filter state
          final data = Map<String, dynamic>.from(call.arguments as Map);
          setState(() {
            _filter = AchievementFilter.values[data['filter'] as int];
            _sort = AchievementSort.values[data['sort'] as int];
            _showMissable = data['showMissable'] as bool;
          });
          return true;
        default:
          return null;
      }
    });
  }

  /// Send event to main app
  Future<void> _sendToMain(String event, Map<String, dynamic> data) async {
    debugPrint('SecondaryDisplay: Sending to main - event=$event');
    try {
      final result = await _channel.invokeMethod('sendToMain', {
        'event': event,
        'data': data,
      });
      debugPrint('SecondaryDisplay: Send result=$result');
    } catch (e) {
      debugPrint('SecondaryDisplay: Error sending to main: $e');
    }
  }

  /// Handle filter change - notify main app
  void _onFilterChanged(AchievementFilter filter) {
    setState(() {
      _filter = filter;
      _showMissable = false;
    });
    _sendToMain('filterChanged', {
      'filter': filter.index,
      'showMissable': false,
    });
  }

  /// Handle missable filter - notify main app
  void _onShowMissable() {
    setState(() {
      _showMissable = true;
      _filter = AchievementFilter.all;
    });
    _sendToMain('filterChanged', {
      'filter': AchievementFilter.all.index,
      'showMissable': true,
    });
  }

  /// Handle sort change - notify main app
  void _onSortChanged(AchievementSort sort) {
    setState(() => _sort = sort);
    _sendToMain('sortChanged', {'sort': sort.index});
  }

  /// Handle achievement tap - notify main app to show detail
  void _onAchievementTap(Map<String, dynamic> achievement) {
    debugPrint('SecondaryDisplay: Achievement tapped - ${achievement['Title']}');
    // Show brief visual feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Tapped: ${achievement['Title']}'),
        duration: const Duration(milliseconds: 500),
        behavior: SnackBarBehavior.floating,
      ),
    );
    _sendToMain('achievementTapped', {
      'achievementId': achievement['ID'],
      'achievement': achievement,
    });
  }

  List<Map<String, dynamic>> _parseAchievements(dynamic achievements) {
    if (achievements == null) return [];
    if (achievements is List) {
      return achievements.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    if (achievements is Map) {
      return achievements.values.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  List<Map<String, dynamic>> _getFilteredAchievements() {
    var filtered = List<Map<String, dynamic>>.from(_achievements);

    // Apply filter
    if (_showMissable) {
      filtered = filtered.where((a) => _isMissable(a)).toList();
    } else {
      switch (_filter) {
        case AchievementFilter.earned:
          filtered = filtered.where((a) => _isEarned(a)).toList();
          break;
        case AchievementFilter.unearned:
          filtered = filtered.where((a) => !_isEarned(a)).toList();
          break;
        case AchievementFilter.all:
          break;
      }
    }

    // Apply sort
    switch (_sort) {
      case AchievementSort.points:
        filtered.sort((a, b) => (b['Points'] ?? 0).compareTo(a['Points'] ?? 0));
        break;
      case AchievementSort.rarity:
        filtered.sort((a, b) => (a['NumAwarded'] ?? 0).compareTo(b['NumAwarded'] ?? 0));
        break;
      case AchievementSort.normal:
        // Default order, unearned first
        filtered.sort((a, b) {
          final aEarned = _isEarned(a);
          final bEarned = _isEarned(b);
          if (aEarned == bEarned) return 0;
          return aEarned ? 1 : -1;
        });
        break;
    }

    return filtered;
  }

  bool _isEarned(Map<String, dynamic> achievement) {
    return achievement['DateEarned'] != null ||
           achievement['DateEarnedHardcore'] != null;
  }

  bool _isMissable(Map<String, dynamic> achievement) {
    // Match main screen's logic exactly
    final type = (achievement['Type'] ?? achievement['type'] ?? '').toString().toLowerCase();
    final flags = achievement['Flags'] ?? achievement['flags'] ?? 0;
    return type == 'missable' ||
           type.contains('missable') ||
           flags == 4 ||
           (flags is int && (flags & 4) != 0);
  }

  @override
  Widget build(BuildContext context) {
    if (_gameData == null) {
      return _buildWaitingScreen();
    }

    return Scaffold(
      body: Column(
        children: [
          _buildHeader(),
          _buildFilterBar(),
          Expanded(
            child: _buildAchievementsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingScreen() {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '🎮',
              style: TextStyle(fontSize: 48, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            Text(
              'Select a game on the main screen',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Achievements will appear here',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final title = _gameData?['gameTitle'] ?? 'Unknown Game';
    final earned = _gameData?['earnedCount'] ?? 0;
    final total = _gameData?['achievementCount'] ?? 0;
    final progress = total > 0 ? earned / total : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1e1e2e),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            // Game icon
            if (_gameData?['imageUrl'] != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  _gameData!['imageUrl'],
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 36,
                    height: 36,
                    color: Colors.grey[800],
                    child: const Center(child: Text('🎮', style: TextStyle(fontSize: 16))),
                  ),
                ),
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.grey[800],
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                      minHeight: 4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Achievement count badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🏆', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 4),
                  Text(
                    '$earned/$total',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1a1a2a),
        border: Border(
          bottom: BorderSide(color: Colors.grey[800]!, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Filter chips
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    label: 'All',
                    selected: _filter == AchievementFilter.all && !_showMissable,
                    onTap: () => _onFilterChanged(AchievementFilter.all),
                  ),
                  const SizedBox(width: 6),
                  _FilterChip(
                    label: '✓ Earned',
                    selected: _filter == AchievementFilter.earned,
                    onTap: () => _onFilterChanged(AchievementFilter.earned),
                    color: Colors.green,
                  ),
                  const SizedBox(width: 6),
                  _FilterChip(
                    label: '○ Unearned',
                    selected: _filter == AchievementFilter.unearned,
                    onTap: () => _onFilterChanged(AchievementFilter.unearned),
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 6),
                  _FilterChip(
                    label: '⚠ Missable',
                    selected: _showMissable,
                    onTap: _onShowMissable,
                    color: Colors.red,
                  ),
                ],
              ),
            ),
          ),
          // Sort button
          PopupMenuButton<AchievementSort>(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text('Sort ▼', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
            ),
            onSelected: _onSortChanged,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: AchievementSort.normal,
                child: Row(
                  children: [
                    Text(
                      _sort == AchievementSort.normal ? '✓' : '  ',
                      style: const TextStyle(color: Colors.green),
                    ),
                    const SizedBox(width: 8),
                    const Text('Default'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: AchievementSort.points,
                child: Row(
                  children: [
                    Text(
                      _sort == AchievementSort.points ? '✓' : '  ',
                      style: const TextStyle(color: Colors.green),
                    ),
                    const SizedBox(width: 8),
                    const Text('By Points'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: AchievementSort.rarity,
                child: Row(
                  children: [
                    Text(
                      _sort == AchievementSort.rarity ? '✓' : '  ',
                      style: const TextStyle(color: Colors.green),
                    ),
                    const SizedBox(width: 8),
                    const Text('By Rarity'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementsList() {
    final filtered = _getFilteredAchievements();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _showMissable ? '⚠' : '🏆',
              style: TextStyle(fontSize: 36, color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            Text(
              _showMissable
                  ? 'No missable achievements'
                  : 'No achievements match filter',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        return _SecondaryAchievementTile(
          achievement: filtered[index],
          numDistinctPlayers: _numDistinctPlayers,
          onTap: () => _onAchievementTap(filtered[index]),
        );
      },
    );
  }
}

/// Filter chip widget
class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? Colors.blue;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? chipColor.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? chipColor : Colors.grey[700]!,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? chipColor : Colors.grey[400],
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

/// Achievement tile matching main screen style
/// Uses Unicode characters instead of Material Icons
class _SecondaryAchievementTile extends StatelessWidget {
  final Map<String, dynamic> achievement;
  final int numDistinctPlayers;
  final VoidCallback onTap;

  const _SecondaryAchievementTile({
    required this.achievement,
    required this.numDistinctPlayers,
    required this.onTap,
  });

  bool get isEarned =>
    achievement['DateEarned'] != null ||
    achievement['DateEarnedHardcore'] != null;

  bool get isMissable {
    // Match main screen's logic exactly
    final type = (achievement['Type'] ?? achievement['type'] ?? '').toString().toLowerCase();
    final flags = achievement['Flags'] ?? achievement['flags'] ?? 0;
    return type == 'missable' ||
           type.contains('missable') ||
           flags == 4 ||
           (flags is int && (flags & 4) != 0);
  }

  Map<String, dynamic> _getRarityInfo(int numAwarded) {
    if (numDistinctPlayers > 0) {
      final percent = (numAwarded / numDistinctPlayers) * 100;
      if (percent < 5) return {'label': 'Ultra Rare', 'color': Colors.red};
      if (percent < 15) return {'label': 'Rare', 'color': Colors.purple};
      if (percent < 40) return {'label': 'Uncommon', 'color': Colors.blue};
      return {'label': 'Common', 'color': Colors.blueGrey};
    }
    if (numAwarded < 100) return {'label': 'Ultra Rare', 'color': Colors.red};
    if (numAwarded < 500) return {'label': 'Rare', 'color': Colors.purple};
    if (numAwarded < 2000) return {'label': 'Uncommon', 'color': Colors.blue};
    return {'label': 'Common', 'color': Colors.blueGrey};
  }

  @override
  Widget build(BuildContext context) {
    final title = achievement['Title'] ?? 'Achievement';
    final description = achievement['Description'] ?? '';
    final points = achievement['Points'] ?? 0;
    final badgeName = achievement['BadgeName'] ?? '';
    final numAwarded = achievement['NumAwarded'] ?? 0;
    final rarityInfo = _getRarityInfo(numAwarded);
    final rarityColor = rarityInfo['color'] as Color;

    // Calculate unlock percentage for rarity bar
    final unlockPercent = numDistinctPlayers > 0
        ? (numAwarded / numDistinctPlayers * 100).clamp(0.0, 100.0)
        : 0.0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Badge with earned indicator
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: ColorFiltered(
                      colorFilter: isEarned
                          ? const ColorFilter.mode(Colors.transparent, BlendMode.dst)
                          : const ColorFilter.matrix(<double>[
                              0.2126, 0.7152, 0.0722, 0, 0,
                              0.2126, 0.7152, 0.0722, 0, 0,
                              0.2126, 0.7152, 0.0722, 0, 0,
                              0, 0, 0, 0.6, 0,
                            ]),
                      child: badgeName.isNotEmpty
                          ? Image.network(
                              'https://retroachievements.org/Badge/$badgeName.png',
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _buildFallbackBadge(),
                            )
                          : _buildFallbackBadge(),
                    ),
                  ),
                  if (isEarned)
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                        child: const Text('✓', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 10),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title row with points
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: isEarned ? Colors.grey[500] : Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('★', style: TextStyle(color: Colors.amber, fontSize: 10)),
                              const SizedBox(width: 2),
                              Text(
                                '$points',
                                style: TextStyle(
                                  color: Colors.amber[400],
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    // Description
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[400],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    // Rarity bar
                    Stack(
                      children: [
                        Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: rarityColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: unlockPercent / 100,
                          child: Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: rarityColor,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Badges row
                    Row(
                      children: [
                        // Rarity badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: rarityColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            rarityInfo['label'] as String,
                            style: TextStyle(
                              color: rarityColor,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (isMissable) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('⚠', style: TextStyle(color: Colors.red, fontSize: 9)),
                                SizedBox(width: 2),
                                Text(
                                  'Missable',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const Spacer(),
                        // Unlock percentage
                        if (numDistinctPlayers > 0)
                          Text(
                            '${unlockPercent.toStringAsFixed(1)}%',
                            style: TextStyle(
                              color: rarityColor,
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              // Tap indicator
              Text(
                '›',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackBadge() {
    return Container(
      width: 44,
      height: 44,
      color: Colors.grey[800],
      child: const Center(child: Text('🏆', style: TextStyle(fontSize: 20))),
    );
  }
}
