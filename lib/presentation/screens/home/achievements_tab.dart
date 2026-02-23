import 'package:flutter/material.dart';
import '../../../core/animations.dart';
import 'home_widgets.dart';

class AchievementsTab extends StatelessWidget {
  final List<dynamic>? achievements;
  final bool isLoading;
  final VoidCallback onRefresh;

  const AchievementsTab({
    super.key,
    required this.achievements,
    required this.isLoading,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recent Achievements'),
      ),
      body: isLoading
          ? _buildShimmerLoading()
          : RetroRefreshIndicator(
              onRefresh: () async => onRefresh(),
              child: achievements == null || achievements!.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 100),
                        EmptyStateWidget(
                          icon: Icons.emoji_events_outlined,
                          title: 'No achievements yet',
                          subtitle: 'Start playing to earn achievements!\n\nPull down to refresh',
                          iconColor: Colors.amber,
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: achievements!.length,
                      itemBuilder: (ctx, i) {
                        return AnimatedListItem(
                          index: i,
                          child: RecentAchievementTile(achievement: achievements![i]),
                        );
                      },
                    ),
            ),
    );
  }

  Widget _buildShimmerLoading() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: List.generate(6, (_) => const Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: ShimmerAchievementTile(),
      )),
    );
  }
}
