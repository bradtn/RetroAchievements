import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/datasources/ra_api_datasource.dart';

/// Authentication state
enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  error,
}

/// Auth state class
class AuthState {
  final AuthStatus status;
  final String? username;
  final String? error;

  const AuthState({
    this.status = AuthStatus.unauthenticated,
    this.username,
    this.error,
  });

  AuthState copyWith({
    AuthStatus? status,
    String? username,
    String? error,
  }) {
    return AuthState(
      status: status ?? this.status,
      username: username ?? this.username,
      error: error,
    );
  }

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isLoading => status == AuthStatus.loading;
}

/// Provider for API data source
final apiDataSourceProvider = Provider<RAApiDataSource>((ref) {
  return RAApiDataSource();
});

/// Auth state notifier
class AuthNotifier extends StateNotifier<AuthState> {
  final RAApiDataSource _apiDataSource;

  // DEV MODE: Hardcoded credentials for development
  static const _devMode = true;
  static const _devUsername = 'BradTN';
  static const _devApiKey = 'whDjKBobMOyql6A4PBiiNEka4FIXhLCb';

  AuthNotifier({required RAApiDataSource apiDataSource})
      : _apiDataSource = apiDataSource,
        super(const AuthState()) {
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    // DEV MODE: Auto-login
    if (_devMode) {
      _apiDataSource.setCredentials(_devUsername, _devApiKey);
      state = AuthState(
        status: AuthStatus.authenticated,
        username: _devUsername,
      );
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString('ra_username');
      final apiKey = prefs.getString('ra_api_key');

      if (username != null && apiKey != null && username.isNotEmpty && apiKey.isNotEmpty) {
        _apiDataSource.setCredentials(username, apiKey);
        state = AuthState(
          status: AuthStatus.authenticated,
          username: username,
        );
      }
    } catch (e) {
      // Ignore errors, stay unauthenticated
    }
  }

  /// Login with username and API key
  Future<bool> login(String username, String apiKey) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);

    try {
      // Set credentials first
      _apiDataSource.setCredentials(username, apiKey);

      // Try to fetch user profile to validate
      final profile = await _apiDataSource.getUserProfile(username);

      if (profile != null) {
        // Save credentials
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('ra_username', username);
        await prefs.setString('ra_api_key', apiKey);

        state = AuthState(
          status: AuthStatus.authenticated,
          username: username,
        );
        return true;
      } else {
        _apiDataSource.clearCredentials();
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          error: 'Invalid username or API key',
        );
        return false;
      }
    } catch (e) {
      _apiDataSource.clearCredentials();
      state = state.copyWith(
        status: AuthStatus.error,
        error: e.toString(),
      );
      return false;
    }
  }

  /// Logout
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('ra_username');
    await prefs.remove('ra_api_key');
    _apiDataSource.clearCredentials();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

/// Provider for auth state
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    apiDataSource: ref.watch(apiDataSourceProvider),
  );
});
