import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import 'user_compare_screen.dart';

// Friends provider
class FriendsNotifier extends StateNotifier<List<String>> {
  static const _key = 'friends_list';

  FriendsNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_key);
    if (json != null) {
      state = List<String>.from(jsonDecode(json));
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(state));
  }

  Future<void> addFriend(String username) async {
    if (!state.contains(username.toLowerCase())) {
      state = [...state, username];
      await _save();
    }
  }

  Future<void> removeFriend(String username) async {
    state = state.where((f) => f.toLowerCase() != username.toLowerCase()).toList();
    await _save();
  }

  bool isFriend(String username) => state.any((f) => f.toLowerCase() == username.toLowerCase());
}

final friendsProvider = StateNotifierProvider<FriendsNotifier, List<String>>((ref) {
  return FriendsNotifier();
});

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  final _usernameController = TextEditingController();
  final Map<String, Map<String, dynamic>?> _friendProfiles = {};
  bool _isLoadingProfiles = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _loadFriendProfiles());
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _loadFriendProfiles() async {
    final friends = ref.read(friendsProvider);
    if (friends.isEmpty) return;

    setState(() => _isLoadingProfiles = true);
    final api = ref.read(apiDataSourceProvider);

    for (final friend in friends) {
      if (!_friendProfiles.containsKey(friend)) {
        final profile = await api.getUserProfile(friend);
        _friendProfiles[friend] = profile;
      }
    }

    setState(() => _isLoadingProfiles = false);
  }

  Future<void> _addFriend() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) return;

    // Verify user exists
    final api = ref.read(apiDataSourceProvider);
    final profile = await api.getUserProfile(username);

    if (profile == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('User "$username" not found')),
        );
      }
      return;
    }

    await ref.read(friendsProvider.notifier).addFriend(username);
    _friendProfiles[username] = profile;
    _usernameController.clear();
    setState(() {});

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added $username as friend')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final friends = ref.watch(friendsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
      ),
      body: Column(
        children: [
          // Add friend input
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      hintText: 'Add friend by username...',
                      prefixIcon: const Icon(Icons.person_add),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                    ),
                    onSubmitted: (_) => _addFriend(),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _addFriend,
                  child: const Text('Add'),
                ),
              ],
            ),
          ),

          // Friends list
          Expanded(
            child: friends.isEmpty
                ? _buildEmptyState()
                : _isLoadingProfiles
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                        onRefresh: () async {
                          _friendProfiles.clear();
                          await _loadFriendProfiles();
                        },
                        child: ListView.builder(
                          padding: EdgeInsets.fromLTRB(
                            16, 0, 16,
                            16 + MediaQuery.of(context).viewPadding.bottom,
                          ),
                          itemCount: friends.length,
                          itemBuilder: (ctx, i) => _FriendTile(
                            username: friends[i],
                            profile: _friendProfiles[friends[i]],
                            onRemove: () => _removeFriend(friends[i]),
                            onCompare: () => _compareFriend(friends[i]),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 80, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text(
              'No Friends Yet',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Add friends by their RetroAchievements username to track their progress',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }

  void _removeFriend(String username) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Friend'),
        content: Text('Remove $username from your friends list?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(friendsProvider.notifier).removeFriend(username);
              _friendProfiles.remove(username);
              Navigator.pop(ctx);
              setState(() {});
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _compareFriend(String username) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => UserCompareScreen(compareUsername: username)),
    );
  }
}

class _FriendTile extends StatelessWidget {
  final String username;
  final Map<String, dynamic>? profile;
  final VoidCallback onRemove;
  final VoidCallback onCompare;

  const _FriendTile({
    required this.username,
    required this.profile,
    required this.onRemove,
    required this.onCompare,
  });

  @override
  Widget build(BuildContext context) {
    if (profile == null) {
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.grey[800],
            child: Text(username[0].toUpperCase()),
          ),
          title: Text(username),
          subtitle: const Text('Loading...'),
        ),
      );
    }

    final points = profile!['TotalPoints'] ?? 0;
    final truePoints = profile!['TotalTruePoints'] ?? 0;
    final richPresence = profile!['RichPresenceMsg'] ?? 'Offline';
    final userPic = profile!['UserPic'] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundImage: userPic.isNotEmpty
                      ? CachedNetworkImageProvider('https://retroachievements.org$userPic')
                      : null,
                  backgroundColor: Colors.grey[800],
                  child: userPic.isEmpty ? Text(username[0].toUpperCase()) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        username,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        richPresence,
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Status indicator
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: richPresence.toLowerCase().contains('offline')
                        ? Colors.grey
                        : Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Stats
            Row(
              children: [
                Expanded(
                  child: _StatChip(
                    icon: Icons.stars,
                    value: _formatNumber(points),
                    label: 'Points',
                    color: Colors.amber,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatChip(
                    icon: Icons.military_tech,
                    value: _formatNumber(truePoints),
                    label: 'True Pts',
                    color: Colors.purple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onCompare,
                  icon: const Icon(Icons.compare_arrows, size: 18),
                  label: const Text('Compare'),
                ),
                TextButton.icon(
                  onPressed: onRemove,
                  icon: const Icon(Icons.person_remove, size: 18),
                  label: const Text('Remove'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatNumber(dynamic num) {
    if (num == null) return '0';
    final n = int.tryParse(num.toString()) ?? 0;
    if (n >= 1000000) {
      return '${(n / 1000000).toStringAsFixed(1)}M';
    } else if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(1)}K';
    }
    return n.toString();
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
