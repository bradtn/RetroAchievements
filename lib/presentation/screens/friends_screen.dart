import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme_utils.dart';
import '../providers/auth_provider.dart';
import '../providers/ra_status_provider.dart';
import 'user_compare_screen.dart';
import 'profile_screen.dart';
import 'friends/friends_provider.dart';
import 'friends/friends_widgets.dart';

export 'friends/friends_provider.dart';

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _usernameController = TextEditingController();

  final Map<String, Map<String, dynamic>?> _friendProfiles = {};
  bool _isLoadingFriends = false;

  List<Map<String, dynamic>> _following = [];
  bool _isLoadingFollowing = false;
  String? _followingError;

  List<Map<String, dynamic>> _followers = [];
  bool _isLoadingFollowers = false;
  String? _followersError;

  bool? _showFriendsInfo;
  static const String _friendsInfoDismissedKey = 'friends_info_dismissed';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadFriendsInfoState();
    Future.microtask(() {
      _loadFollowing();
      _loadFollowers();
      _tryLoadFriendProfiles();
    });
  }

  Future<void> _loadFriendsInfoState() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _showFriendsInfo = !(prefs.getBool(_friendsInfoDismissedKey) ?? false);
      });
    }
  }

  Future<void> _dismissFriendsInfo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_friendsInfoDismissedKey, true);
    if (mounted) {
      setState(() => _showFriendsInfo = false);
    }
  }

  void _tryLoadFriendProfiles() {
    final friendsState = ref.read(friendsProvider);
    if (!friendsState.isLoading && friendsState.friends.isNotEmpty) {
      _loadFriendProfiles(friendsState.friends);
    } else if (friendsState.isLoading) {
      // Provider still loading, wait and retry
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _tryLoadFriendProfiles();
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _loadFriendProfiles([List<Friend>? friendsList]) async {
    final friends = friendsList ?? ref.read(friendsProvider).friends;
    if (friends.isEmpty) return;

    setState(() => _isLoadingFriends = true);
    final api = ref.read(apiDataSourceProvider);

    for (final friend in friends) {
      if (!_friendProfiles.containsKey(friend.username)) {
        final profile = await api.getUserProfile(friend.username);
        if (mounted) {
          _friendProfiles[friend.username] = profile;
        }
      }
    }

    if (mounted) {
      setState(() => _isLoadingFriends = false);
    }
  }

  Future<void> _loadFollowing() async {
    setState(() {
      _isLoadingFollowing = true;
      _followingError = null;
    });

    final api = ref.read(apiDataSourceProvider);
    final result = await api.getUsersIFollow();

    if (result != null) {
      ref.read(raStatusProvider.notifier).reportSuccess();
      setState(() {
        _following = List<Map<String, dynamic>>.from(result);
        _isLoadingFollowing = false;
      });
    } else {
      ref.read(raStatusProvider.notifier).reportFailure('Following list failed');
      setState(() {
        _followingError = ref.read(raStatusProvider.notifier).getErrorMessage(
          'Unable to load following list. Pull down to retry.',
        );
        _isLoadingFollowing = false;
      });
    }
  }

  Future<void> _loadFollowers() async {
    setState(() {
      _isLoadingFollowers = true;
      _followersError = null;
    });

    final api = ref.read(apiDataSourceProvider);
    final result = await api.getUsersFollowingMe();

    if (result != null) {
      ref.read(raStatusProvider.notifier).reportSuccess();
      setState(() {
        _followers = List<Map<String, dynamic>>.from(result);
        _isLoadingFollowers = false;
      });
    } else {
      ref.read(raStatusProvider.notifier).reportFailure('Followers list failed');
      setState(() {
        _followersError = ref.read(raStatusProvider.notifier).getErrorMessage(
          'Unable to load followers list. Pull down to retry.',
        );
        _isLoadingFollowers = false;
      });
    }
  }

  Future<void> _addFriend() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) return;

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
        SnackBar(content: Text('Added $username to your friends list')),
      );
    }
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

  void _viewProfile(String username) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProfileScreen(username: username)),
    );
  }

  Future<void> _addToLocalFriends(String username) async {
    if (username.isEmpty) return;

    final friendsState = ref.read(friendsProvider);
    if (friendsState.isFriend(username)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$username is already in your friends list')),
      );
      return;
    }

    final api = ref.read(apiDataSourceProvider);
    final profile = await api.getUserProfile(username);

    await ref.read(friendsProvider.notifier).addFriend(username);
    if (profile != null) {
      _friendProfiles[username] = profile;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added $username to your friends list')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Social'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.people), text: 'My Friends'),
            Tab(icon: Icon(Icons.person_add), text: 'Following'),
            Tab(icon: Icon(Icons.group), text: 'Followers'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMyFriendsTab(),
          _buildFollowingTab(),
          _buildFollowersTab(),
        ],
      ),
    );
  }

  Widget _buildMyFriendsTab() {
    final friendsState = ref.watch(friendsProvider);
    final friends = friendsState.friends;

    return Column(
      children: [
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
        if (_showFriendsInfo == true) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _buildFriendsInfoBanner(),
          ),
        ],
        Expanded(
          child: friendsState.isLoading
              ? const Center(child: CircularProgressIndicator())
              : friends.isEmpty
                  ? const EmptyFriendsState(
                      icon: Icons.people_outline,
                      title: 'No Friends Yet',
                      subtitle: 'Add players by username to track their progress',
                    )
                  : _isLoadingFriends
                      ? const Center(child: CircularProgressIndicator())
                      : RefreshIndicator(
                          onRefresh: () async {
                            _friendProfiles.clear();
                            await _loadFriendProfiles();
                          },
                          child: ListView.builder(
                            padding: EdgeInsets.fromLTRB(
                              16, 8, 16,
                              16 + MediaQuery.of(context).viewPadding.bottom,
                            ),
                            itemCount: friends.length,
                            itemBuilder: (ctx, i) {
                              final friend = friends[i];
                              return FriendTile(
                                username: friend.username,
                                profile: _friendProfiles[friend.username],
                                onRemove: () => _removeFriend(friend.username),
                                onCompare: () => _compareFriend(friend.username),
                                onTap: () => _viewProfile(friend.username),
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _buildFollowingTab() {
    if (_isLoadingFollowing) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_followingError != null) {
      return ErrorState(error: _followingError!, onRetry: _loadFollowing);
    }

    if (_following.isEmpty) {
      return const EmptyFriendsState(
        icon: Icons.person_add_disabled,
        title: 'Not Following Anyone',
        subtitle: 'Follow other players on retroachievements.org to see them here',
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            'Manage who you follow on retroachievements.org',
            style: TextStyle(color: context.subtitleColor, fontSize: 12),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadFollowing,
            child: ListView.builder(
              padding: EdgeInsets.fromLTRB(
                16, 8, 16,
                16 + MediaQuery.of(context).viewPadding.bottom,
              ),
              itemCount: _following.length,
              itemBuilder: (ctx, i) => RAUserTile(
                userData: _following[i],
                onTap: () => _viewProfile(_following[i]['User'] ?? _following[i]['user'] ?? ''),
                onCompare: () => _compareFriend(_following[i]['User'] ?? _following[i]['user'] ?? ''),
                onAddToFriends: () => _addToLocalFriends(_following[i]['User'] ?? _following[i]['user'] ?? ''),
                isFollowing: true,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFollowersTab() {
    if (_isLoadingFollowers) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_followersError != null) {
      return ErrorState(error: _followersError!, onRetry: _loadFollowers);
    }

    if (_followers.isEmpty) {
      return const EmptyFriendsState(
        icon: Icons.group_off,
        title: 'No Followers Yet',
        subtitle: 'Other players who follow you on retroachievements.org will appear here',
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            'Players following you on retroachievements.org',
            style: TextStyle(color: context.subtitleColor, fontSize: 12),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadFollowers,
            child: ListView.builder(
              padding: EdgeInsets.fromLTRB(
                16, 8, 16,
                16 + MediaQuery.of(context).viewPadding.bottom,
              ),
              itemCount: _followers.length,
              itemBuilder: (ctx, i) => RAUserTile(
                userData: _followers[i],
                onTap: () => _viewProfile(_followers[i]['User'] ?? _followers[i]['user'] ?? ''),
                onCompare: () => _compareFriend(_followers[i]['User'] ?? _followers[i]['user'] ?? ''),
                onAddToFriends: () => _addToLocalFriends(_followers[i]['User'] ?? _followers[i]['user'] ?? ''),
                isFollowing: false,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFriendsInfoBanner() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.orange.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline,
              size: 20,
              color: Colors.orange[300],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'App-Local Friends List',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.orange[200],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'This friends list is stored locally in the app only. '
                    'It\'s separate from RetroAchievements Following/Followers. '
                    'Use it to track any player\'s progress.',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.subtitleColor,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _dismissFriendsInfo,
              child: Icon(
                Icons.close,
                size: 18,
                color: Colors.orange[300],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
