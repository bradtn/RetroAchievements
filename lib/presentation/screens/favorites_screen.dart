import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme_utils.dart';
import '../../core/animations.dart';
import '../providers/favorites_provider.dart';
import 'game_detail_screen.dart';
import 'game_search_screen.dart';
import 'favorites/favorites_widgets.dart';

export 'favorites/favorites_widgets.dart';

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen>
    with TickerProviderStateMixin {
  late AnimationController _listAnimationController;
  late AnimationController _emptyStateController;
  late Animation<double> _emptyIconScale;
  late Animation<double> _emptyContentFade;
  late Animation<Offset> _emptyButtonSlide;

  @override
  void initState() {
    super.initState();
    _listAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _emptyStateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _emptyIconScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _emptyStateController,
        curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
      ),
    );

    _emptyContentFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _emptyStateController,
        curve: const Interval(0.3, 0.7, curve: Curves.easeOut),
      ),
    );

    _emptyButtonSlide = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _emptyStateController,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOutCubic),
      ),
    );
  }

  @override
  void dispose() {
    _listAnimationController.dispose();
    _emptyStateController.dispose();
    super.dispose();
  }

  void _navigateToSearch() {
    Haptics.light();
    Navigator.push(
      context,
      SlidePageRoute(page: const GameSearchScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final favState = ref.watch(favoritesProvider);

    // Trigger appropriate animation
    if (favState.favorites.isEmpty && !favState.isLoading) {
      _emptyStateController.forward();
    } else if (favState.favorites.isNotEmpty) {
      _listAnimationController.forward();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorites'),
      ),
      body: favState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : favState.favorites.isEmpty
              ? _buildEmptyState(context)
              : _buildFavoritesList(context, ref, favState),
      floatingActionButton: favState.favorites.isNotEmpty
          ? ScaleTransition(
              scale: CurvedAnimation(
                parent: _listAnimationController,
                curve: const Interval(0.6, 1.0, curve: Curves.elasticOut),
              ),
              child: FloatingActionButton.extended(
                onPressed: _navigateToSearch,
                icon: const Icon(Icons.add),
                label: const Text('Add Game'),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
            )
          : null,
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return AnimatedBuilder(
      animation: _emptyStateController,
      builder: (context, child) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated star icon
                ScaleTransition(
                  scale: _emptyIconScale,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.star_outline,
                      size: 64,
                      color: Colors.amber,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                // Text content
                FadeTransition(
                  opacity: _emptyContentFade,
                  child: Column(
                    children: [
                      Text(
                        'No Favorites Yet',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Track your progress on games you\'re playing.\nAdd games to see them here!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: context.subtitleColor,
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                // Animated button
                SlideTransition(
                  position: _emptyButtonSlide,
                  child: FadeTransition(
                    opacity: _emptyContentFade,
                    child: FilledButton.icon(
                      onPressed: _navigateToSearch,
                      icon: const Icon(Icons.search),
                      label: const Text('Find Games'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFavoritesList(BuildContext context, WidgetRef ref, FavoritesState state) {
    final pinned = state.getPinned();
    final others = state.favorites.where((f) => !f.isPinned).toList();

    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return AnimatedBuilder(
      animation: _listAnimationController,
      builder: (context, child) {
        int itemIndex = 0;

        return ListView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 80 + bottomPadding), // Extra padding for FAB
          children: [
            // Pinned game (for widget)
            if (pinned != null) ...[
              _buildAnimatedItem(
                itemIndex++,
                Row(
                  children: [
                    const Icon(Icons.push_pin, size: 16, color: Colors.amber),
                    const SizedBox(width: 8),
                    Text(
                      'PINNED FOR WIDGET',
                      style: TextStyle(
                        color: Colors.amber[400],
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _buildAnimatedItem(
                itemIndex++,
                FavoriteCard(
                  game: pinned,
                  isPinned: true,
                  onTap: () => _openGame(pinned),
                  onUnpin: () => ref.read(favoritesProvider.notifier).unpinAll(),
                  onRemove: () => ref.read(favoritesProvider.notifier).removeFavorite(pinned.gameId),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Other favorites
            if (others.isNotEmpty) ...[
              _buildAnimatedItem(
                itemIndex++,
                Text(
                  'TRACKING ${others.length} GAME${others.length == 1 ? '' : 'S'}',
                  style: TextStyle(
                    color: context.subtitleColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ...others.map((game) {
                final index = itemIndex++;
                return _buildAnimatedItem(
                  index,
                  FavoriteCard(
                    game: game,
                    isPinned: false,
                    onTap: () => _openGame(game),
                    onPin: () => ref.read(favoritesProvider.notifier).setPinned(game.gameId),
                    onRemove: () => ref.read(favoritesProvider.notifier).removeFavorite(game.gameId),
                  ),
                );
              }),
            ],
          ],
        );
      },
    );
  }

  Widget _buildAnimatedItem(int index, Widget child) {
    final itemDelay = index * 0.1;
    final itemEnd = (itemDelay + 0.4).clamp(0.0, 1.0);
    final progress = ((_listAnimationController.value - itemDelay) / (itemEnd - itemDelay)).clamp(0.0, 1.0);

    final slide = Curves.easeOutCubic.transform(progress);
    final fade = Curves.easeOut.transform(progress);

    return Transform.translate(
      offset: Offset(0, 30 * (1 - slide)),
      child: Opacity(
        opacity: fade,
        child: child,
      ),
    );
  }

  void _openGame(FavoriteGame game) {
    Navigator.push(
      context,
      SlidePageRoute(
        page: GameDetailScreen(
          gameId: game.gameId,
          gameTitle: game.title,
        ),
      ),
    );
  }
}
