import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/animations.dart';
import '../../providers/auth_provider.dart';
import '../profile_screen.dart';

class LeaderboardTile extends StatelessWidget {
  final Map<String, dynamic> leaderboard;
  final VoidCallback onTap;

  const LeaderboardTile({
    required this.leaderboard,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Debug: print all keys in leaderboard data
    debugPrint('LeaderboardTile keys: ${leaderboard.keys.toList()}');
    debugPrint('LeaderboardTile data: $leaderboard');

    final title = leaderboard['Title'] ?? 'Leaderboard';
    final description = leaderboard['Description'] ?? '';
    // Try various field names the API might use for entry count
    final numEntries = leaderboard['NumEntries'] ??
                       leaderboard['NumResults'] ??
                       leaderboard['EntryCount'] ??
                       leaderboard['Count'] ??
                       leaderboard['TotalEntries'] ??
                       leaderboard['Entries'] ??
                       0;
    final format = leaderboard['Format'] ?? (leaderboard['LowerIsBetter'] != null ? 'time' : '');

    // Determine icon based on format/type
    IconData icon = Icons.leaderboard;
    Color iconColor = Colors.amber;
    if (format.toLowerCase().contains('time') || format.toLowerCase().contains('speed')) {
      icon = Icons.timer;
      iconColor = Colors.blue;
    } else if (format.toLowerCase().contains('score') || format.toLowerCase().contains('point')) {
      icon = Icons.stars;
      iconColor = Colors.amber;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: () {
          Haptics.light();
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[400]
                              : Colors.grey[600],
                          fontSize: 12,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Show "View" badge instead of count (API doesn't provide count in list)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'View',
                  style: TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

class LeaderboardDetailDialog extends ConsumerStatefulWidget {
  final int leaderboardId;
  final String title;
  final String description;
  final String format;

  const LeaderboardDetailDialog({
    required this.leaderboardId,
    required this.title,
    required this.description,
    required this.format,
  });

  @override
  ConsumerState<LeaderboardDetailDialog> createState() => LeaderboardDetailDialogState();
}

class LeaderboardDetailDialogState extends ConsumerState<LeaderboardDetailDialog> {
  List<Map<String, dynamic>> _entries = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final api = ref.read(apiDataSourceProvider);
    final result = await api.getLeaderboardEntries(widget.leaderboardId, count: 100);

    if (mounted) {
      if (result != null) {
        // The API returns entries in a 'Results' or 'Entries' key typically
        final entries = result['Results'] ?? result['Entries'] ?? result['entries'] ?? [];
        setState(() {
          _entries = List<Map<String, dynamic>>.from(entries);
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load leaderboard entries';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authProvider).username;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.leaderboard, color: Colors.amber),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (widget.description.isNotEmpty)
                              Text(
                                widget.description,
                                style: TextStyle(
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Entries list
            Flexible(
              child: _isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : _error != null
                      ? Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error, color: Colors.red, size: 48),
                              const SizedBox(height: 16),
                              Text(_error!),
                              const SizedBox(height: 16),
                              FilledButton(
                                onPressed: _loadEntries,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : _entries.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(32),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.hourglass_empty, color: Colors.grey, size: 48),
                                  SizedBox(height: 16),
                                  Text('No entries yet'),
                                ],
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: _entries.length,
                              itemBuilder: (ctx, i) {
                                final entry = _entries[i];
                                final rank = entry['Rank'] ?? entry['rank'] ?? i + 1;
                                final user = entry['User'] ?? entry['user'] ?? entry['Username'] ?? 'Unknown';
                                final score = entry['Score'] ?? entry['score'] ?? 0;
                                final formattedScore = entry['FormattedScore'] ?? entry['ScoreFormatted'] ?? '$score';
                                // Construct avatar URL from username (standard RA format)
                                final userPicUrl = 'https://retroachievements.org/UserPic/$user.png';
                                final isCurrentUser = user.toString().toLowerCase() == currentUser?.toLowerCase();

                                // Rank medal colors
                                Color? medalColor;
                                IconData? medalIcon;
                                if (rank == 1) {
                                  medalColor = Colors.amber;
                                  medalIcon = Icons.emoji_events;
                                } else if (rank == 2) {
                                  medalColor = Colors.grey[400];
                                  medalIcon = Icons.emoji_events;
                                } else if (rank == 3) {
                                  medalColor = Colors.orange[700];
                                  medalIcon = Icons.emoji_events;
                                }

                                return GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ProfileScreen(username: user.toString()),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isCurrentUser
                                          ? Colors.amber.withValues(alpha: 0.15)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                      border: isCurrentUser
                                          ? Border.all(color: Colors.amber.withValues(alpha: 0.3))
                                          : null,
                                    ),
                                    child: Row(
                                      children: [
                                        // Rank
                                        SizedBox(
                                          width: 36,
                                          child: medalIcon != null
                                              ? Icon(medalIcon, color: medalColor, size: 22)
                                              : Text(
                                                  '#$rank',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: isCurrentUser ? Colors.amber : Colors.grey,
                                                  ),
                                                ),
                                        ),
                                        // Avatar
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(16),
                                          child: CachedNetworkImage(
                                            imageUrl: userPicUrl,
                                            width: 32,
                                            height: 32,
                                            fit: BoxFit.cover,
                                            placeholder: (_, __) => _buildDefaultAvatar(user.toString()),
                                            errorWidget: (_, __, ___) => _buildDefaultAvatar(user.toString()),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        // Username (tappable)
                                        Expanded(
                                          child: Text(
                                            user.toString(),
                                            style: TextStyle(
                                              fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal,
                                              color: isCurrentUser ? Colors.amber : null,
                                            ),
                                          ),
                                        ),
                                        // Score
                                        Text(
                                          formattedScore,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: medalColor ?? (isCurrentUser ? Colors.amber : null),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar(String username) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.grey[700],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          username.isNotEmpty ? username[0].toUpperCase() : '?',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }
}

/// Animated rarity distribution chart
