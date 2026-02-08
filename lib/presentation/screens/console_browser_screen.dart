import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme_utils.dart';
import '../../data/cache/game_cache.dart';
import '../providers/auth_provider.dart';
import 'game_detail_screen.dart';

class ConsoleBrowserScreen extends ConsumerStatefulWidget {
  const ConsoleBrowserScreen({super.key});

  @override
  ConsumerState<ConsoleBrowserScreen> createState() => _ConsoleBrowserScreenState();
}

class _ConsoleBrowserScreenState extends ConsumerState<ConsoleBrowserScreen> {
  List<dynamic>? _consoles;
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadConsoles();
  }

  Future<void> _loadConsoles() async {
    setState(() => _isLoading = true);
    final api = ref.read(apiDataSourceProvider);
    final consoles = await api.getConsoles();
    setState(() {
      _consoles = consoles;
      _isLoading = false;
    });
  }

  List<dynamic> get _filteredConsoles {
    if (_consoles == null) return [];
    if (_searchQuery.isEmpty) return _consoles!;
    return _consoles!.where((c) {
      final name = (c['Name'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  // Console icon mapping
  IconData _getConsoleIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('playstation') || lower.contains('ps1') || lower.contains('ps2') || lower.contains('psp')) {
      return Icons.sports_esports;
    } else if (lower.contains('nintendo') || lower.contains('nes') || lower.contains('snes') || lower.contains('game boy') || lower.contains('n64')) {
      return Icons.videogame_asset;
    } else if (lower.contains('sega') || lower.contains('genesis') || lower.contains('saturn') || lower.contains('dreamcast')) {
      return Icons.gamepad;
    } else if (lower.contains('atari')) {
      return Icons.games;
    } else if (lower.contains('arcade')) {
      return Icons.local_activity;
    } else if (lower.contains('pc')) {
      return Icons.computer;
    }
    return Icons.videogame_asset;
  }

  Color _getConsoleColor(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('playstation') || lower.contains('ps1') || lower.contains('ps2') || lower.contains('psp')) {
      return Colors.blue;
    } else if (lower.contains('nintendo') || lower.contains('nes') || lower.contains('snes') || lower.contains('game boy') || lower.contains('n64')) {
      return Colors.red;
    } else if (lower.contains('sega') || lower.contains('genesis') || lower.contains('saturn') || lower.contains('dreamcast')) {
      return Colors.blueAccent;
    } else if (lower.contains('atari')) {
      return Colors.orange;
    } else if (lower.contains('arcade')) {
      return Colors.purple;
    }
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Browse by Console'),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search consoles...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          // Console list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredConsoles.isEmpty
                    ? const Center(child: Text('No consoles found'))
                    : RefreshIndicator(
                        onRefresh: _loadConsoles,
                        child: ListView.builder(
                          padding: EdgeInsets.fromLTRB(
                            16, 0, 16,
                            16 + MediaQuery.of(context).viewPadding.bottom,
                          ),
                          itemCount: _filteredConsoles.length,
                          itemBuilder: (ctx, i) {
                            final console = _filteredConsoles[i];
                            final name = console['Name'] ?? 'Unknown';
                            final id = console['ID'];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: _getConsoleColor(name).withValues(alpha: 0.2),
                                  child: Icon(
                                    _getConsoleIcon(name),
                                    color: _getConsoleColor(name),
                                  ),
                                ),
                                title: Text(name),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => _ConsoleGamesScreen(
                                        consoleId: int.tryParse(id.toString()) ?? 0,
                                        consoleName: name,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

// Games list for a specific console
class _ConsoleGamesScreen extends ConsumerStatefulWidget {
  final int consoleId;
  final String consoleName;

  const _ConsoleGamesScreen({
    required this.consoleId,
    required this.consoleName,
  });

  @override
  ConsumerState<_ConsoleGamesScreen> createState() => _ConsoleGamesScreenState();
}

class _ConsoleGamesScreenState extends ConsumerState<_ConsoleGamesScreen> {
  List<dynamic>? _games;
  bool _isLoading = true;
  String _searchQuery = '';
  String _sortBy = 'title'; // title, achievements, points
  bool _hideNoAchievements = false;

  @override
  void initState() {
    super.initState();
    _loadGames();
  }

  Future<void> _loadGames() async {
    setState(() => _isLoading = true);
    final api = ref.read(apiDataSourceProvider);
    final games = await api.getGameList(widget.consoleId);
    setState(() {
      _games = games;
      _isLoading = false;
    });

    // Cache games for future use
    if (games != null) {
      GameCache.instance.init().then((_) {
        GameCache.instance.putAll(
          games.map((g) => Map<String, dynamic>.from(g)).toList(),
        );
      });
    }
  }

  List<dynamic> get _filteredGames {
    if (_games == null) return [];
    var filtered = _games!.where((g) {
      final title = (g['Title'] ?? '').toString().toLowerCase();
      final matchesSearch = _searchQuery.isEmpty || title.contains(_searchQuery.toLowerCase());
      final hasAchievements = (g['NumAchievements'] ?? 0) > 0;
      final passesFilter = !_hideNoAchievements || hasAchievements;
      return matchesSearch && passesFilter;
    }).toList();

    // Sort
    filtered.sort((a, b) {
      switch (_sortBy) {
        case 'achievements':
          final aAch = a['NumAchievements'] ?? 0;
          final bAch = b['NumAchievements'] ?? 0;
          return (bAch as int).compareTo(aAch as int);
        case 'points':
          final aPts = a['Points'] ?? 0;
          final bPts = b['Points'] ?? 0;
          return (bPts as int).compareTo(aPts as int);
        default:
          final aTitle = (a['Title'] ?? '').toString();
          final bTitle = (b['Title'] ?? '').toString();
          return aTitle.compareTo(bTitle);
      }
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.consoleName),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (v) => setState(() => _sortBy = v),
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'title',
                child: Row(
                  children: [
                    if (_sortBy == 'title') const Icon(Icons.check, size: 18),
                    const SizedBox(width: 8),
                    const Text('Sort by Title'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'achievements',
                child: Row(
                  children: [
                    if (_sortBy == 'achievements') const Icon(Icons.check, size: 18),
                    const SizedBox(width: 8),
                    const Text('Sort by Achievements'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'points',
                child: Row(
                  children: [
                    if (_sortBy == 'points') const Icon(Icons.check, size: 18),
                    const SizedBox(width: 8),
                    const Text('Sort by Points'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search games...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          // Games count and filter
          if (!_isLoading && _games != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    '${_filteredGames.length} games',
                    style: TextStyle(color: context.subtitleColor),
                  ),
                  const Spacer(),
                  FilterChip(
                    label: const Text('Has achievements'),
                    selected: _hideNoAchievements,
                    onSelected: (v) => setState(() => _hideNoAchievements = v),
                    showCheckmark: true,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          // Games list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredGames.isEmpty
                    ? const Center(child: Text('No games found'))
                    : RefreshIndicator(
                        onRefresh: _loadGames,
                        child: ListView.builder(
                          padding: EdgeInsets.fromLTRB(
                            16, 0, 16,
                            16 + MediaQuery.of(context).viewPadding.bottom,
                          ),
                          itemCount: _filteredGames.length,
                          itemBuilder: (ctx, i) => _GameTile(game: _filteredGames[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _GameTile extends StatelessWidget {
  final dynamic game;

  const _GameTile({required this.game});

  @override
  Widget build(BuildContext context) {
    final title = game['Title'] ?? 'Unknown';
    final gameId = game['ID'];
    final numAchievements = game['NumAchievements'] ?? 0;
    final points = game['Points'] ?? 0;
    final imageIcon = game['ImageIcon'] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: imageIcon.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: 'https://retroachievements.org$imageIcon',
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    width: 48,
                    height: 48,
                    color: Colors.grey[800],
                    child: const Icon(Icons.games),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    width: 48,
                    height: 48,
                    color: Colors.grey[800],
                    child: const Icon(Icons.games),
                  ),
                )
              : Container(
                  width: 48,
                  height: 48,
                  color: Colors.grey[800],
                  child: const Icon(Icons.games),
                ),
        ),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: numAchievements > 0
            ? Row(
                children: [
                  Icon(Icons.emoji_events, size: 14, color: Colors.amber[400]),
                  const SizedBox(width: 4),
                  Text('$numAchievements'),
                  const SizedBox(width: 12),
                  Icon(Icons.stars, size: 14, color: Colors.purple[300]),
                  const SizedBox(width: 4),
                  Text('$points pts'),
                ],
              )
            : Text(
                'No achievements yet',
                style: TextStyle(color: context.subtitleColor, fontStyle: FontStyle.italic),
              ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GameDetailScreen(
                gameId: int.tryParse(gameId.toString()) ?? 0,
                gameTitle: title,
              ),
            ),
          );
        },
      ),
    );
  }
}
