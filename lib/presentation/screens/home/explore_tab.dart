import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/animations.dart';
import '../game_search_screen.dart';
import '../live_feed_screen.dart';
import '../milestones/milestones_screen.dart';
import '../favorites_screen.dart';
import '../events_screen.dart';
import '../console_browser_screen.dart';
import '../leaderboard_screen.dart';
import '../friends_screen.dart';
import '../calendar_screen.dart';
import '../trophy_case_screen.dart';

class ExploreTab extends StatefulWidget {
  final bool isSelected;

  const ExploreTab({super.key, required this.isSelected});

  @override
  State<ExploreTab> createState() => _ExploreTabState();
}

class _ExploreTabState extends State<ExploreTab> with TickerProviderStateMixin {
  bool _hasNewEvents = false;
  late AnimationController _animationController;
  bool _hasAnimated = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _checkForNewEvents();
  }

  @override
  void didUpdateWidget(ExploreTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected && !oldWidget.isSelected && !_hasAnimated) {
      _hasAnimated = true;
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkForNewEvents() async {
    final prefs = await SharedPreferences.getInstance();

    // Check for new AOTW
    final lastKnownAotwId = prefs.getString('last_known_aotw_id') ?? '';
    final lastViewedAotwId = prefs.getString('last_viewed_aotw_id') ?? '';
    final hasNewAotw = lastKnownAotwId.isNotEmpty && lastKnownAotwId != lastViewedAotwId;

    // Check for new AotM
    final lastKnownAotmId = prefs.getString('last_known_aotm_id') ?? '';
    final lastViewedAotmId = prefs.getString('last_viewed_aotm_id') ?? '';
    final hasNewAotm = lastKnownAotmId.isNotEmpty && lastKnownAotmId != lastViewedAotmId;

    if (mounted && (hasNewAotw || hasNewAotm)) {
      setState(() => _hasNewEvents = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      _ExploreItem(
        icon: Icons.search,
        title: 'Search',
        color: Colors.pink,
        onTap: () => Navigator.push(context, SlidePageRoute(page: const GameSearchScreen())),
      ),
      _ExploreItem(
        icon: Icons.rss_feed,
        title: 'Live Feed',
        color: Colors.red,
        hasLiveIndicator: true,
        onTap: () => Navigator.push(context, SlidePageRoute(page: const LiveFeedScreen())),
      ),
      _ExploreItem(
        icon: Icons.military_tech,
        title: 'Awards',
        color: Colors.purple,
        onTap: () => Navigator.push(context, SlidePageRoute(page: const MilestonesScreen())),
      ),
      _ExploreItem(
        icon: Icons.star,
        title: 'Favorites',
        color: Colors.amber,
        onTap: () => Navigator.push(context, SlidePageRoute(page: const FavoritesScreen())),
      ),
      _ExploreItem(
        icon: Icons.emoji_events,
        title: 'Events',
        color: Colors.orange,
        showNewBadge: _hasNewEvents,
        onTap: () {
          setState(() => _hasNewEvents = false);
          Navigator.push(context, SlidePageRoute(page: const EventsScreen()));
        },
      ),
      _ExploreItem(
        icon: Icons.videogame_asset,
        title: 'Consoles',
        color: Colors.blue,
        onTap: () => Navigator.push(context, SlidePageRoute(page: const ConsoleBrowserScreen())),
      ),
      _ExploreItem(
        icon: Icons.leaderboard,
        title: 'Leaderboard',
        color: Colors.green,
        onTap: () => Navigator.push(context, SlidePageRoute(page: const LeaderboardScreen())),
      ),
      _ExploreItem(
        icon: Icons.people,
        title: 'Friends',
        color: Colors.teal,
        onTap: () => Navigator.push(context, SlidePageRoute(page: const FriendsScreen())),
      ),
      _ExploreItem(
        icon: Icons.workspace_premium,
        title: 'Trophies',
        color: Colors.amber,
        onTap: () => Navigator.push(context, SlidePageRoute(page: const TrophyCaseScreen())),
      ),
      _ExploreItem(
        icon: Icons.local_fire_department,
        title: 'Streaks',
        color: Colors.orange,
        isPremium: true,
        onTap: () => Navigator.push(context, SlidePageRoute(page: const CalendarScreen())),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Explore')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final padding = 12.0;
          final spacing = 12.0;
          final availableWidth = constraints.maxWidth - (padding * 2);
          final availableHeight = constraints.maxHeight - (padding * 2);

          // Determine columns based on screen width
          int crossAxisCount;
          if (availableWidth < 400) {
            crossAxisCount = 2;
          } else if (availableWidth < 600) {
            crossAxisCount = 3;
          } else if (availableWidth < 900) {
            crossAxisCount = 4;
          } else {
            crossAxisCount = 5;
          }

          // Calculate tile dimensions to fit all tiles without scrolling
          final totalHorizontalSpacing = (crossAxisCount - 1) * spacing;
          final tileWidth = (availableWidth - totalHorizontalSpacing) / crossAxisCount;
          final rowCount = (items.length / crossAxisCount).ceil();
          final totalVerticalSpacing = (rowCount - 1) * spacing;
          final tileHeight = (availableHeight - totalVerticalSpacing) / rowCount;

          // Use dynamic ratio - tiles auto-fit any screen shape
          final aspectRatio = tileWidth / tileHeight;

          return Padding(
            padding: EdgeInsets.all(padding),
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: spacing,
                    crossAxisSpacing: spacing,
                    childAspectRatio: aspectRatio,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    if (!_hasAnimated || _animationController.isCompleted) {
                      return _ExploreGridItem(item: items[index]);
                    }

                    final itemDelay = index * 0.06;
                    final itemEnd = (itemDelay + 0.5).clamp(0.0, 1.0);
                    final progress = ((_animationController.value - itemDelay) / (itemEnd - itemDelay)).clamp(0.0, 1.0);

                    final scale = Curves.elasticOut.transform(progress);
                    final opacity = Curves.easeOut.transform(progress);

                    return Transform.scale(
                      scale: 0.6 + (0.4 * scale),
                      child: Opacity(
                        opacity: opacity,
                        child: _ExploreGridItem(item: items[index]),
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _ExploreItem {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;
  final bool isPremium;
  final bool showNewBadge;
  final bool hasLiveIndicator;

  const _ExploreItem({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
    this.isPremium = false,
    this.showNewBadge = false,
    this.hasLiveIndicator = false,
  });
}

class _ExploreGridItem extends StatelessWidget {
  final _ExploreItem item;

  const _ExploreGridItem({required this.item});

  @override
  Widget build(BuildContext context) {
    return TappableCard(
      onTap: item.onTap,
      child: Card(
        child: Stack(
          children: [
            // Use FittedBox to scale content down on small tiles
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: item.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _buildIcon(),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (item.isPremium)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'PRO',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            if (item.showNewBadge)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'NEW',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon() {
    if (item.hasLiveIndicator) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withValues(alpha: 0.5),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Icon(item.icon, color: item.color, size: 24),
        ],
      );
    }
    return Icon(item.icon, color: item.color, size: 24);
  }
}
