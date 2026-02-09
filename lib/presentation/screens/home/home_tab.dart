import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/animations.dart';
import '../share_card/share_card_screen.dart';
import '../stats_screen.dart';
import 'home_widgets.dart';

class HomeTab extends StatelessWidget {
  final Map<String, dynamic>? profile;
  final List<dynamic>? recentGames;
  final bool isLoading;
  final VoidCallback onRefresh;

  const HomeTab({
    super.key,
    required this.profile,
    required this.recentGames,
    required this.isLoading,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _buildShimmerLoading();
    }

    return RetroRefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 40),
          if (profile != null) _buildProfileHeader(context),
          const SizedBox(height: 24),
          if (profile != null) _buildStatsRow(context),
          const SizedBox(height: 16),
          AnimatedListItem(
            index: 0,
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    SlidePageRoute(page: const StatsScreen()),
                  );
                },
                icon: const Icon(Icons.analytics),
                label: const Text('View Detailed Stats'),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('Recently Played', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (recentGames != null && recentGames!.isNotEmpty)
            ...recentGames!.take(5).toList().asMap().entries.map((entry) =>
              AnimatedListItem(
                index: entry.key,
                child: GameListTile(game: entry.value),
              ),
            )
          else
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No recent games'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 40),
        const ShimmerProfileHeader(),
        const SizedBox(height: 24),
        const Row(
          children: [
            Expanded(child: ShimmerCard(height: 100)),
            SizedBox(width: 12),
            Expanded(child: ShimmerCard(height: 100)),
          ],
        ),
        const SizedBox(height: 40),
        const ShimmerCard(height: 20, width: 150),
        const SizedBox(height: 12),
        ...List.generate(4, (_) => const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: ShimmerGameTile(),
        )),
      ],
    );
  }

  Widget _buildProfileHeader(BuildContext context) {
    final picUrl = 'https://retroachievements.org${profile!['UserPic']}';
    final username = profile!['User'] ?? 'User';
    return Row(
      children: [
        ClipOval(
          child: CachedNetworkImage(
            imageUrl: picUrl,
            width: 80,
            height: 80,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              width: 80,
              height: 80,
              color: Colors.grey[800],
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              width: 80,
              height: 80,
              color: Colors.grey[800],
              child: Center(
                child: Text(
                  username.isNotEmpty ? username[0].toUpperCase() : '?',
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                username,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                profile!['RichPresenceMsg'] ?? 'Offline',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.share),
          onPressed: () {
            Navigator.push(
              context,
              FadeScalePageRoute(
                page: ShareCardScreen(
                  type: ShareCardType.profile,
                  data: profile!,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildStatsRow(BuildContext context) {
    return Row(
      children: [
        Expanded(child: StatCard(
          icon: Icons.stars,
          label: 'Points',
          value: '${profile!['TotalPoints'] ?? 0}',
          color: Colors.amber,
        )),
        const SizedBox(width: 12),
        Expanded(child: StatCard(
          icon: Icons.military_tech,
          label: 'True Points',
          value: '${profile!['TotalTruePoints'] ?? 0}',
          color: Colors.purple,
        )),
      ],
    );
  }
}
