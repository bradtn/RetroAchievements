import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';

/// A friend entry (app-local, not synced with RA)
class Friend {
  final String username;
  final String? userPic;
  final int? points;
  final String? richPresence;
  final DateTime addedAt;

  Friend({
    required this.username,
    this.userPic,
    this.points,
    this.richPresence,
    required this.addedAt,
  });

  Map<String, dynamic> toJson() => {
    'username': username,
    'userPic': userPic,
    'points': points,
    'richPresence': richPresence,
    'addedAt': addedAt.toIso8601String(),
  };

  factory Friend.fromJson(Map<String, dynamic> json) => Friend(
    username: json['username'] ?? '',
    userPic: json['userPic'],
    points: json['points'],
    richPresence: json['richPresence'],
    addedAt: DateTime.tryParse(json['addedAt'] ?? '') ?? DateTime.now(),
  );

  Friend copyWith({
    String? username,
    String? userPic,
    int? points,
    String? richPresence,
    DateTime? addedAt,
  }) => Friend(
    username: username ?? this.username,
    userPic: userPic ?? this.userPic,
    points: points ?? this.points,
    richPresence: richPresence ?? this.richPresence,
    addedAt: addedAt ?? this.addedAt,
  );
}

class FriendsState {
  final List<Friend> friends;
  final bool isLoading;

  FriendsState({
    this.friends = const [],
    this.isLoading = true,
  });

  FriendsState copyWith({
    List<Friend>? friends,
    bool? isLoading,
  }) => FriendsState(
    friends: friends ?? this.friends,
    isLoading: isLoading ?? this.isLoading,
  );

  bool isFriend(String username) =>
    friends.any((f) => f.username.toLowerCase() == username.toLowerCase());
}

class FriendsNotifier extends Notifier<FriendsState> {
  static const _storageKey = 'friends_list_v2';

  @override
  FriendsState build() {
    _load();
    return FriendsState();
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

final friendsProvider = NotifierProvider<FriendsNotifier, FriendsState>(FriendsNotifier.new);
