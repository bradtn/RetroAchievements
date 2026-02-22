import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/animations.dart';
import '../../providers/auth_provider.dart';
import '../profile_screen.dart';

class LeaderboardTile extends StatelessWidget {
  final Map<String, dynamic> leaderboard;
  final VoidCallback onTap;
  final Map<String, dynamic>? userEntry; // User's entry for this leaderboard (if any)

  const LeaderboardTile({
    required this.leaderboard,
    required this.onTap,
    this.userEntry,
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
              // Show user's rank if they have an entry, otherwise show "View" badge
              if (userEntry != null) ...[
                _buildUserRankBadge(context),
              ] else ...[
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
              ],
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserRankBadge(BuildContext context) {
    final userEntryData = userEntry!['UserEntry'] as Map<String, dynamic>? ?? userEntry!;
    final rank = userEntryData['Rank'] ?? userEntry!['Rank'] ?? 0;
    final formattedScore = userEntryData['FormattedScore'] ??
                           userEntryData['Score']?.toString() ??
                           userEntry!['FormattedScore'] ??
                           userEntry!['Score']?.toString() ?? '';

    // Color based on rank
    Color rankColor = Colors.green;
    if (rank == 1) {
      rankColor = Colors.amber;
    } else if (rank == 2) {
      rankColor = Colors.grey[400]!;
    } else if (rank == 3) {
      rankColor = Colors.orange[700]!;
    } else if (rank <= 10) {
      rankColor = Colors.blue;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Rank badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: rankColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.emoji_events, size: 12, color: rankColor),
              const SizedBox(width: 3),
              Text(
                '#$rank',
                style: TextStyle(
                  fontSize: 11,
                  color: rankColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        if (formattedScore.isNotEmpty) ...[
          const SizedBox(width: 6),
          // Score badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              formattedScore,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class LeaderboardDetailDialog extends ConsumerStatefulWidget {
  final int leaderboardId;
  final String title;
  final String description;
  final String format;
  final Map<String, dynamic>? userEntry; // User's entry for this leaderboard (if any)
  final String? gameTitle;
  final String? gameIcon;
  final VoidCallback? onShare;

  const LeaderboardDetailDialog({
    required this.leaderboardId,
    required this.title,
    required this.description,
    required this.format,
    this.userEntry,
    this.gameTitle,
    this.gameIcon,
    this.onShare,
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
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiDataSourceProvider);

      // Add a local timeout to prevent indefinite hangs
      final result = await api.getLeaderboardEntries(widget.leaderboardId, count: 100)
          .timeout(const Duration(seconds: 15), onTimeout: () => null);

      if (!mounted) return;

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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error loading leaderboard';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authProvider).username;
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final screenWidth = mediaQuery.size.width;
    // Use up to 85% of screen height to ensure all entries are visible
    final maxDialogHeight = (screenHeight * 0.85).clamp(400.0, 800.0);
    final maxDialogWidth = (screenWidth * 0.9).clamp(300.0, 500.0);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxDialogWidth,
          maxHeight: maxDialogHeight,
          minWidth: 280,
          minHeight: 200,
        ),
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
                      if (widget.onShare != null && widget.userEntry != null)
                        IconButton(
                          onPressed: widget.onShare,
                          icon: const Icon(Icons.share, size: 20),
                          tooltip: 'Share',
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
                          : _buildEntriesListWithUserPosition(currentUser),
            ),
          ],
        ),
      ),
    );
  }

  /// Build entries list showing top 10 + user's position at bottom if not in top 10
  Widget _buildEntriesListWithUserPosition(String? currentUser) {
    // Take top 10 entries for display
    final displayEntries = _entries.take(10).toList();

    // Check if user is in the displayed entries
    bool userInTopEntries = false;
    for (final entry in displayEntries) {
      final user = entry['User'] ?? entry['user'] ?? entry['Username'] ?? '';
      if (user.toString().toLowerCase() == currentUser?.toLowerCase()) {
        userInTopEntries = true;
        break;
      }
    }

    // Get user entry from widget prop if not in top entries
    final userEntryData = widget.userEntry;
    final showUserAtBottom = !userInTopEntries && userEntryData != null;

    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: displayEntries.length + (showUserAtBottom ? 2 : 0), // +1 separator +1 user entry
      itemBuilder: (ctx, i) {
        // Show separator before user entry
        if (showUserAtBottom && i == displayEntries.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(child: Divider(color: Colors.grey[600])),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'Your Position',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: Colors.grey[600])),
              ],
            ),
          );
        }

        // Show user entry at bottom
        if (showUserAtBottom && i == displayEntries.length + 1) {
          final nestedUserEntry = userEntryData['UserEntry'] as Map<String, dynamic>? ?? userEntryData;
          final rank = nestedUserEntry['Rank'] ?? userEntryData['Rank'] ?? 0;
          final formattedScore = nestedUserEntry['FormattedScore'] ??
                                 nestedUserEntry['Score']?.toString() ??
                                 userEntryData['FormattedScore'] ??
                                 userEntryData['Score']?.toString() ?? '';
          return _buildEntryRow(
            rank: rank,
            user: currentUser ?? 'You',
            formattedScore: formattedScore,
            isCurrentUser: true,
          );
        }

        // Show regular entry
        final entry = displayEntries[i];
        final rank = entry['Rank'] ?? entry['rank'] ?? i + 1;
        final user = entry['User'] ?? entry['user'] ?? entry['Username'] ?? 'Unknown';
        final score = entry['Score'] ?? entry['score'] ?? 0;
        final formattedScore = entry['FormattedScore'] ?? entry['ScoreFormatted'] ?? '$score';
        final isCurrentUser = user.toString().toLowerCase() == currentUser?.toLowerCase();

        return _buildEntryRow(
          rank: rank,
          user: user.toString(),
          formattedScore: formattedScore,
          isCurrentUser: isCurrentUser,
        );
      },
    );
  }

  /// Build a single entry row
  Widget _buildEntryRow({
    required dynamic rank,
    required String user,
    required String formattedScore,
    required bool isCurrentUser,
  }) {
    final userPicUrl = 'https://retroachievements.org/UserPic/$user.png';

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
            builder: (_) => ProfileScreen(username: user),
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
                placeholder: (_, __) => _buildDefaultAvatar(user),
                errorWidget: (_, __, ___) => _buildDefaultAvatar(user),
              ),
            ),
            const SizedBox(width: 10),
            // Username
            Expanded(
              child: Text(
                user,
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
