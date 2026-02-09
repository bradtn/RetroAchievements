import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
