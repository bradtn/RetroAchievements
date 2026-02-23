import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/animations.dart';
import '../../../core/responsive_utils.dart';
import '../game_search_screen.dart';
import '../live_feed_screen.dart';
import '../milestones/milestones_screen.dart';
import '../favorites_screen.dart';
import '../aotw_screen.dart';
import '../aotm_screen.dart';
import '../console_browser_screen.dart';
import '../leaderboard_screen.dart';
import '../friends_screen.dart';
import '../calendar_screen.dart';

class ExploreTab extends StatefulWidget {
  final bool isSelected;

  const ExploreTab({super.key, required this.isSelected});

  @override
  State<ExploreTab> createState() => _ExploreTabState();
}

class _ExploreTabState extends State<ExploreTab> with TickerProviderStateMixin {
  bool _hasNewAotw = false;
  bool _hasNewAotm = false;
  late AnimationController _animationController;
  bool _hasAnimated = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _checkForNewAotw();
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

  Future<void> _checkForNewAotw() async {
    final prefs = await SharedPreferences.getInstance();
    final lastKnownId = prefs.getString('last_known_aotw_id') ?? '';
    final lastViewedId = prefs.getString('last_viewed_aotw_id') ?? '';

    if (mounted && lastKnownId.isNotEmpty && lastKnownId != lastViewedId) {
      setState(() => _hasNewAotw = true);
    }

    // Also check for new AotM
    final lastKnownAotmId = prefs.getString('last_known_aotm_id') ?? '';
    final lastViewedAotmId = prefs.getString('last_viewed_aotm_id') ?? '';

    if (mounted && lastKnownAotmId.isNotEmpty && lastKnownAotmId != lastViewedAotmId) {
      setState(() => _hasNewAotm = true);
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
        title: 'AOTW',
        color: Colors.orange,
        showNewBadge: _hasNewAotw,
        onTap: () {
          setState(() => _hasNewAotw = false);
          Navigator.push(context, SlidePageRoute(page: const AchievementOfTheWeekScreen()));
        },
      ),
      _ExploreItem(
        icon: Icons.calendar_month,
        title: 'AOTM',
        color: Colors.deepPurple,
        showNewBadge: _hasNewAotm,
        onTap: () {
          setState(() => _hasNewAotm = false);
          Navigator.push(context, SlidePageRoute(page: const AchievementOfTheMonthScreen()));
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
          // Calculate optimal grid layout to fit all tiles without scrolling
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

          // Calculate rows needed
          final rowCount = (items.length / crossAxisCount).ceil();

          // Calculate tile dimensions to fit everything
          final totalHorizontalSpacing = (crossAxisCount - 1) * spacing;
          final tileWidth = (availableWidth - totalHorizontalSpacing) / crossAxisCount;

          final totalVerticalSpacing = (rowCount - 1) * spacing;
          final tileHeight = (availableHeight - totalVerticalSpacing) / rowCount;

          // Use aspect ratio that fits the available space
          final childAspectRatio = tileWidth / tileHeight;

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
                    childAspectRatio: childAspectRatio,
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
            Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                    flex: 3,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: item.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: _buildIcon(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Flexible(
                    flex: 1,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        item.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (item.isPremium)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: const Text(
                    'PRO',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 7,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            if (item.showNewBadge)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: const Text(
                    'NEW',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 7,
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
