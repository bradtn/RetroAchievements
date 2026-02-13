import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/datasources/ra_api_datasource.dart';
import '../../providers/auth_provider.dart';

/// A friend entry
class Friend {
  final String username;
  final String? userPic;
  final int? points;
  final String? richPresence;
  final DateTime addedAt;
  final bool fromRAFriendList; // Synced from RA friend list

  Friend({
    required this.username,
    this.userPic,
    this.points,
    this.richPresence,
    required this.addedAt,
    this.fromRAFriendList = false,
  });

  Map<String, dynamic> toJson() => {
    'username': username,
    'userPic': userPic,
    'points': points,
    'richPresence': richPresence,
    'addedAt': addedAt.toIso8601String(),
    'fromRAFriendList': fromRAFriendList,
  };

  factory Friend.fromJson(Map<String, dynamic> json) => Friend(
    username: json['username'] ?? '',
    userPic: json['userPic'],
    points: json['points'],
    richPresence: json['richPresence'],
    addedAt: DateTime.tryParse(json['addedAt'] ?? '') ?? DateTime.now(),
    fromRAFriendList: json['fromRAFriendList'] ?? false,
  );

  Friend copyWith({
    String? username,
    String? userPic,
    int? points,
    String? richPresence,
    DateTime? addedAt,
    bool? fromRAFriendList,
  }) => Friend(
    username: username ?? this.username,
    userPic: userPic ?? this.userPic,
    points: points ?? this.points,
    richPresence: richPresence ?? this.richPresence,
    addedAt: addedAt ?? this.addedAt,
    fromRAFriendList: fromRAFriendList ?? this.fromRAFriendList,
  );
}

class FriendsState {
  final List<Friend> friends;
  final bool isLoading;
  final bool isSyncing;

  FriendsState({
    this.friends = const [],
    this.isLoading = true,
    this.isSyncing = false,
  });

  FriendsState copyWith({
    List<Friend>? friends,
    bool? isLoading,
    bool? isSyncing,
  }) => FriendsState(
    friends: friends ?? this.friends,
    isLoading: isLoading ?? this.isLoading,
    isSyncing: isSyncing ?? this.isSyncing,
  );

  bool isFriend(String username) =>
    friends.any((f) => f.username.toLowerCase() == username.toLowerCase());
}

class FriendsNotifier extends StateNotifier<FriendsState> {
  static const _storageKey = 'friends_list_v2';
  final RAApiDataSource? _api;
  final String? _username;

  FriendsNotifier({RAApiDataSource? api, String? username})
      : _api = api,
        _username = username,
        super(FriendsState()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_storageKey);
    if (json != null) {
      try {
        final list = jsonDecode(json) as List<dynamic>;
        final friends = list.map((e) => Friend.fromJson(e)).toList();
        state = state.copyWith(friends: friends, isLoading: false);
      } catch (_) {
        state = state.copyWith(isLoading: false);
      }
    } else {
      state = state.copyWith(isLoading: false);
    }

    // Sync from RA friend list after loading local friends
    if (_api != null && _username != null) {
      syncFromRAFriendList();
    }
  }

  /// Sync friends from RA friend list
  Future<void> syncFromRAFriendList() async {
    final api = _api;
    final username = _username;
    if (api == null || username == null) return;

    state = state.copyWith(isSyncing: true);

    try {
      final friendList = await api.getFriendList(username);
      if (friendList == null || friendList.isEmpty) {
        state = state.copyWith(isSyncing: false);
        return;
      }

      bool hasChanges = false;
      final currentFriends = List<Friend>.from(state.friends);

      for (final friendData in friendList) {
        final friendUsername = friendData['User'] ?? friendData['Friend'] ?? '';
        if (friendUsername.isEmpty) continue;

        // Skip if already in friends
        if (currentFriends.any((f) =>
            f.username.toLowerCase() == friendUsername.toString().toLowerCase())) {
          continue;
        }

        // Add to friends with fromRAFriendList flag
        final friend = Friend(
          username: friendUsername.toString(),
          userPic: friendData['UserPic'],
          points: friendData['RAPoints'] ?? friendData['Points'],
          richPresence: friendData['RichPresenceMsg'],
          addedAt: DateTime.now(),
          fromRAFriendList: true,
        );

        currentFriends.add(friend);
        hasChanges = true;
      }

      if (hasChanges) {
        state = state.copyWith(friends: currentFriends, isSyncing: false);
        await _save();
      } else {
        state = state.copyWith(isSyncing: false);
      }
    } catch (e) {
      state = state.copyWith(isSyncing: false);
      // Silently fail - friend list sync is optional
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(state.friends.map((f) => f.toJson()).toList());
    await prefs.setString(_storageKey, json);
  }

  Future<void> addFriend(String username, {String? userPic, int? points}) async {
    if (state.isFriend(username)) return;

    final friend = Friend(
      username: username,
      userPic: userPic,
      points: points,
      addedAt: DateTime.now(),
      fromRAFriendList: false,
    );

    state = state.copyWith(friends: [...state.friends, friend]);
    await _save();
  }

  Future<void> removeFriend(String username) async {
    state = state.copyWith(
      friends: state.friends.where((f) =>
        f.username.toLowerCase() != username.toLowerCase()).toList(),
    );
    await _save();
  }

  Future<void> updateFriendData(String username, {String? userPic, int? points, String? richPresence}) async {
    final index = state.friends.indexWhere((f) =>
      f.username.toLowerCase() == username.toLowerCase());
    if (index == -1) return;

    final updated = state.friends[index].copyWith(
      userPic: userPic,
      points: points,
      richPresence: richPresence,
    );
    final newList = [...state.friends];
    newList[index] = updated;
    state = state.copyWith(friends: newList);
    await _save();
  }

  bool isFriend(String username) => state.isFriend(username);
}

final friendsProvider = StateNotifierProvider<FriendsNotifier, FriendsState>((ref) {
  final api = ref.watch(apiDataSourceProvider);
  final authState = ref.watch(authProvider);
  return FriendsNotifier(api: api, username: authState.username);
});
