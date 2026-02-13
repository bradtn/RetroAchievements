import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  final AudioPlayer _player = AudioPlayer();
  bool _isEnabled = true;
  bool _isInitialized = false;

  bool get isEnabled => _isEnabled;

  Future<void> initialize() async {
    if (_isInitialized) return;

    final prefs = await SharedPreferences.getInstance();
    _isEnabled = prefs.getBool('sound_effects_enabled') ?? true;
    _isInitialized = true;
  }

  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sound_effects_enabled', enabled);
  }

  Future<void> playAchievementUnlock() async {
    if (!_isEnabled) return;

    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/achievement_unlock.wav'));
    } catch (e) {
      // Silently fail if sound can't be played
    }
  }

  Future<void> dispose() async {
    await _player.dispose();
  }
}
