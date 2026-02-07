import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme_utils.dart';
import '../providers/auth_provider.dart';
import 'game_detail_screen.dart';

class GameSearchScreen extends ConsumerStatefulWidget {
  const GameSearchScreen({super.key});

  @override
  ConsumerState<GameSearchScreen> createState() => _GameSearchScreenState();
}

class _GameSearchScreenState extends ConsumerState<GameSearchScreen> {
  final _searchController = TextEditingController();
  List<dynamic>? _consoles;
  List<dynamic>? _recentGames;
  List<dynamic>? _consoleGames;
  int? _selectedConsoleId;
  String? _selectedConsoleName;
  bool _isLoadingConsoles = true;
  bool _isLoadingGames = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final api = ref.read(apiDataSourceProvider);
    final username = ref.read(authProvider).username;

    final results = await Future.wait([
      api.getConsoles(),
      if (username != null) api.getRecentlyPlayedGames(username, count: 20),
    ]);

    setState(() {
      _consoles = results[0] as List<dynamic>?;
      if (results.length > 1) {
        _recentGames = results[1] as List<dynamic>?;
      }
      _isLoadingConsoles = false;
    });
  }

  Future<void> _loadConsoleGames(int consoleId, String consoleName) async {
    setState(() {
      _selectedConsoleId = consoleId;
      _selectedConsoleName = consoleName;
      _isLoadingGames = true;
      _consoleGames = null;
    });

    final api = ref.read(apiDataSourceProvider);
    final games = await api.getGameList(consoleId);

    setState(() {
      _consoleGames = games;
      _isLoadingGames = false;
    });
  }

  void _clearConsoleSelection() {
    setState(() {
      _selectedConsoleId = null;
      _selectedConsoleName = null;
      _consoleGames = null;
    });
  }

  List<dynamic> _getFilteredGames() {
    List<dynamic> games;

    if (_selectedConsoleId != null && _consoleGames != null) {
      games = _consoleGames!;
    } else if (_recentGames != null) {
      games = _recentGames!;
    } else {
      return [];
    }

    if (_searchQuery.isEmpty) {
      return games.take(50).toList();
    }

    final query = _searchQuery.toLowerCase();
    return games
        .where((g) => (g['Title'] ?? '').toString().toLowerCase().contains(query))
        .take(50)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Games'),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: _selectedConsoleName != null
                    ? 'Search $_selectedConsoleName games...'
                    : 'Search your recent games...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),

          // Console selector or back button
          if (_selectedConsoleName != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: _clearConsoleSelection,
                    icon: const Icon(Icons.arrow_back, size: 18),
                    label: const Text('All Consoles'),
                  ),
                  const Spacer(),
                  Chip(
                    avatar: const Icon(Icons.videogame_asset, size: 16),
                    label: Text(_selectedConsoleName!),
                  ),
                ],
              ),
            ),

          // Content
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoadingConsoles) {
      return const Center(child: CircularProgressIndicator());
    }

    // If a console is selected, show games from that console
    if (_selectedConsoleId != null) {
      if (_isLoadingGames) {
        return const Center(child: CircularProgressIndicator());
      }
      return _buildGamesList();
    }

    // Otherwise, show recent games + console selector
    return ListView(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewPadding.bottom + 16,
      ),
      children: [
        // Recent games section
        if (_recentGames != null && _recentGames!.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              _searchQuery.isEmpty ? 'Recently Played' : 'Search Results',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          ..._getFilteredGames().map((game) => _GameTile(game: game)),
          if (_searchQuery.isEmpty) const SizedBox(height: 24),
        ],

        // Console selector
        if (_searchQuery.isEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'Browse by Console',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (_consoles != null)
            ..._consoles!.map((console) => _ConsoleTile(
                  console: console,
                  onTap: () => _loadConsoleGames(
                    console['ID'] as int,
                    console['Name'] as String,
                  ),
                )),
        ],
      ],
    );
  }

  Widget _buildGamesList() {
    final games = _getFilteredGames();

    if (games.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text(
              'No games found',
              style: TextStyle(color: context.subtitleColor),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewPadding.bottom + 16,
      ),
      itemCount: games.length,
      itemBuilder: (context, index) => _GameTile(game: games[index]),
    );
  }
}

class _GameTile extends StatelessWidget {
  final dynamic game;

  const _GameTile({required this.game});

  @override
  Widget build(BuildContext context) {
    final title = game['Title'] ?? 'Unknown';
    final imageIcon = game['ImageIcon'] ?? '';
    final consoleName = game['ConsoleName'] ?? '';
    final gameId = game['GameID'] ?? game['ID'];
    final numAchievements = game['NumAchievements'] ?? game['NumPossibleAchievements'] ?? 0;
    final numAchieved = game['NumAchieved'] ?? game['NumAwardedToUser'] ?? 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        onTap: () {
          if (gameId != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => GameDetailScreen(
                  gameId: gameId is int ? gameId : int.tryParse(gameId.toString()) ?? 0,
                  gameTitle: title,
                ),
              ),
            );
          }
        },
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: 'https://retroachievements.org$imageIcon',
            width: 48,
            height: 48,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => Container(
              width: 48,
              height: 48,
              color: Colors.grey[800],
              child: const Icon(Icons.games),
            ),
          ),
        ),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          consoleName.isNotEmpty ? consoleName : '$numAchievements achievements',
          style: TextStyle(color: context.subtitleColor, fontSize: 12),
        ),
        trailing: numAchieved > 0
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$numAchieved/$numAchievements',
                  style: const TextStyle(color: Colors.green, fontSize: 12),
                ),
              )
            : null,
      ),
    );
  }
}

class _ConsoleTile extends StatelessWidget {
  final dynamic console;
  final VoidCallback onTap;

  const _ConsoleTile({required this.console, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = console['Name'] ?? 'Unknown';
    final iconUrl = console['IconURL'] ?? '';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        onTap: onTap,
        leading: iconUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: 'https://retroachievements.org$iconUrl',
                width: 32,
                height: 32,
                errorWidget: (_, __, ___) => const Icon(Icons.videogame_asset),
              )
            : const Icon(Icons.videogame_asset),
        title: Text(name),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
