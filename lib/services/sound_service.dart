import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class SoundService {
  // Dedizierte Player pro Sound für perfekte Performance
  late final AudioPlayer _correctPlayer;
  late final AudioPlayer _wrongPlayer;
  late final AudioPlayer _startPlayer;
  late final AudioPlayer _endPlayer;
  late final AudioPlayer _countdownPlayer;
  late final AudioPlayer _countdownStartPlayer;
  
  bool _isMuted = false;
  bool _isInitialized = false;

  // Volume settings - Correct dominant, Wrong softer
  static const double _volCorrect = 1.0;
  static const double _volWrong = 0.7;  // Reduziert für softeren Feel
  static const double _volStart = 0.8;
  static const double _volEnd = 0.75;
  static const double _volCountdown = 0.7;
  static const double _volCountdownStart = 0.7;

  SoundService() {
    _correctPlayer = AudioPlayer();
    _wrongPlayer = AudioPlayer();
    _startPlayer = AudioPlayer();
    _endPlayer = AudioPlayer();
    _countdownPlayer = AudioPlayer();
    _countdownStartPlayer = AudioPlayer();
    _initAudioContext();
  }

  Future<void> _initAudioContext() async {
    try {
      // Configure all players for low-latency mode (critical for mobile)
      final players = [
        _correctPlayer,
        _wrongPlayer,
        _startPlayer,
        _endPlayer,
        _countdownPlayer,
        _countdownStartPlayer,
      ];
      
      for (final player in players) {
        await player.setReleaseMode(ReleaseMode.stop);
        
        // Mobile-specific: Set audio context to low latency
        if (!kIsWeb) {
          await player.setPlayerMode(PlayerMode.lowLatency);
        }
      }

      // Preload all sounds for instant playback (critical for mobile)
      await _preloadSounds();
      
      _isInitialized = true;
      
      if (kDebugMode) {
        debugPrint('🔊 SoundService: Initialized with preloaded audio');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ SoundService init error: $e');
      }
    }
  }

  Future<void> _preloadSounds() async {
    try {
      // Preload into memory for zero-latency playback
      await Future.wait([
        _correctPlayer.setSource(AssetSource('sounds/correct.wav')),
        _wrongPlayer.setSource(AssetSource('sounds/wrong.wav')),
        _startPlayer.setSource(AssetSource('sounds/start.wav')),
        _endPlayer.setSource(AssetSource('sounds/end.wav')),
        _countdownPlayer.setSource(AssetSource('sounds/countdown.wav')),
        _countdownStartPlayer.setSource(AssetSource('sounds/countdown_start.wav')),
      ]);
      
      // Set volumes once
      await _correctPlayer.setVolume(_volCorrect);
      await _wrongPlayer.setVolume(_volWrong);
      await _startPlayer.setVolume(_volStart);
      await _endPlayer.setVolume(_volEnd);
      await _countdownPlayer.setVolume(_volCountdown);
      await _countdownStartPlayer.setVolume(_volCountdownStart);
      
      if (kDebugMode) {
        debugPrint('✅ All sounds preloaded');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Preload error: $e');
      }
    }
  }

  /// Call this from a user gesture (e.g. button click) to unlock audio on Web
  Future<void> unlock() async {
    if (kIsWeb && !_isInitialized) {
      // Play silent sound to unlock audio context on web
      try {
        await _startPlayer.setVolume(0.01);
        await _startPlayer.resume();
        await Future.delayed(const Duration(milliseconds: 100));
        await _startPlayer.stop();
        await _startPlayer.setVolume(_volStart);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Unlock error: $e');
        }
      }
    }
  }

  void toggleMute() {
    _isMuted = !_isMuted;
    if (_isMuted) {
      _stopAll();
    }
  }

  void _stopAll() {
    _correctPlayer.stop();
    _wrongPlayer.stop();
    _startPlayer.stop();
    _endPlayer.stop();
    _countdownPlayer.stop();
    _countdownStartPlayer.stop();
  }

  Future<void> _playFromPlayer(AudioPlayer player, String soundName) async {
    if (_isMuted || !_isInitialized) return;

    try {
      // Stop and seek to beginning for instant replay
      await player.stop();
      await player.seek(Duration.zero);
      await player.resume();
      
      if (kDebugMode) {
        debugPrint('🔊 Playing: $soundName');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Error playing $soundName: $e');
      }
    }
  }

  Future<void> playStart() async {
    HapticFeedback.lightImpact();
    await _playFromPlayer(_startPlayer, 'start');
  }

  Future<void> playCorrect() async {
    HapticFeedback.mediumImpact();
    await _playFromPlayer(_correctPlayer, 'correct');
  }

  Future<void> playWrong() async {
    HapticFeedback.heavyImpact();
    await _playFromPlayer(_wrongPlayer, 'wrong');
  }

  Future<void> playEnd() async {
    HapticFeedback.vibrate();
    await _playFromPlayer(_endPlayer, 'end');
  }

  Future<void> playTick() async {
    HapticFeedback.lightImpact();
    // Use start player for tick for now
    await _playFromPlayer(_startPlayer, 'tick');
  }

  Future<void> playCountdown() async {
    await _playFromPlayer(_countdownPlayer, 'countdown');
  }

  Future<void> stopCountdown() async {
    try {
      await _countdownPlayer.stop();
    } catch (_) {}
  }

  Future<void> playCountdownStart() async {
    await _playFromPlayer(_countdownStartPlayer, 'countdown_start');
  }

  Future<void> stopCountdownStart() async {
    try {
      await _countdownStartPlayer.stop();
    } catch (_) {}
  }

  Future<void> playExplosion() async {
    HapticFeedback.heavyImpact();
    await _playFromPlayer(_endPlayer, 'explosion');
  }

  Future<void> playSuccess() async {
    await playCorrect();
  }

  Future<void> playError() async {
    await playWrong();
  }

  Future<void> playClick() async {
    HapticFeedback.selectionClick();
  }

  void dispose() {
    _correctPlayer.dispose();
    _wrongPlayer.dispose();
    _startPlayer.dispose();
    _endPlayer.dispose();
    _countdownPlayer.dispose();
    _countdownStartPlayer.dispose();
    
    if (kDebugMode) {
      debugPrint('🔊 SoundService disposed');
    }
  }
}
