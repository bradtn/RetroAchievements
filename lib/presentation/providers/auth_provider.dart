import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
    this.status = AuthStatus.initial,
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

/// Singleton API data source instance (credentials persist)
final _apiDataSource = RAApiDataSource();

/// Provider for API data source
final apiDataSourceProvider = Provider<RAApiDataSource>((ref) {
  return _apiDataSource;
});

/// Secure storage instance with enhanced security options
const _secureStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(
    encryptedSharedPreferences: true,
  ),
  iOptions: IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  ),
);

/// Storage keys
const _keyUsername = 'ra_username';
const _keyApiKey = 'ra_api_key';

/// Auth state notifier
class AuthNotifier extends Notifier<AuthState> {
  late final RAApiDataSource _apiDataSource;

  @override
  AuthState build() {
    _apiDataSource = ref.watch(apiDataSourceProvider);
    _loadSavedCredentials();
    return const AuthState();
  }

  Future<void> _loadSavedCredentials() async {
    state = state.copyWith(status: AuthStatus.loading);

    try {
      final username = await _secureStorage.read(key: _keyUsername);
      final apiKey = await _secureStorage.read(key: _keyApiKey);

      if (username != null && apiKey != null && username.isNotEmpty && apiKey.isNotEmpty) {
        _apiDataSource.setCredentials(username, apiKey);

        // Validate credentials are still valid
        final profile = await _apiDataSource.getUserProfile(username);
        if (profile != null) {
          state = AuthState(
            status: AuthStatus.authenticated,
            username: username,
          );
        } else {
          // Credentials invalid, clear them
          await _clearStoredCredentials();
          state = const AuthState(status: AuthStatus.unauthenticated);
        }
      } else {
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
    } catch (e) {
      // On error, stay unauthenticated
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> _clearStoredCredentials() async {
    await _secureStorage.delete(key: _keyUsername);
    await _secureStorage.delete(key: _keyApiKey);
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
        // Verify the returned username matches what was entered (case-insensitive)
        final returnedUsername = profile['User']?.toString() ?? '';
        if (returnedUsername.toLowerCase() != username.toLowerCase()) {
          _apiDataSource.clearCredentials();
          state = state.copyWith(
            status: AuthStatus.unauthenticated,
            error: 'Username mismatch. Please enter YOUR RetroAchievements username.',
          );
          return false;
        }

        // Save credentials securely using the exact username from RA
        await _secureStorage.write(key: _keyUsername, value: returnedUsername);
        await _secureStorage.write(key: _keyApiKey, value: apiKey);

        state = AuthState(
          status: AuthStatus.authenticated,
          username: returnedUsername,
        );
        return true;
      } else {
        _apiDataSource.clearCredentials();
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          error: 'Invalid username or API key. Please check your credentials.',
        );
        return false;
      }
    } catch (e) {
      _apiDataSource.clearCredentials();
      state = state.copyWith(
        status: AuthStatus.error,
        error: 'Connection error. Please check your internet and try again.',
      );
      return false;
    }
  }

  /// Logout
  Future<void> logout() async {
    await _clearStoredCredentials();
    _apiDataSource.clearCredentials();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

/// Provider for auth state
final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
