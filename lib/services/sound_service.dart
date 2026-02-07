import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class SoundService {
  // Dedicated player per sound keeps replay latency low.
  late final AudioPlayer _correctPlayer;
  late final AudioPlayer _wrongPlayer;
  late final AudioPlayer _startPlayer;
  late final AudioPlayer _endPlayer;
  late final AudioPlayer _countdownPlayer;
  late final AudioPlayer _countdownStartPlayer;
  late final Map<AudioPlayer, String> _playerAssets;

  final Set<AudioPlayer> _preparedSources = <AudioPlayer>{};
  bool _isMuted = false;
  bool _isInitialized = false;
  Future<void>? _initFuture;

  // Volume settings - Correct dominant, Wrong softer
  static const double _volCorrect = 1.0;
  static const double _volWrong = 0.7;
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
    _playerAssets = <AudioPlayer, String>{
      _correctPlayer: 'sounds/correct.wav',
      _wrongPlayer: 'sounds/wrong.wav',
      _startPlayer: 'sounds/start.wav',
      _endPlayer: 'sounds/end.wav',
      _countdownPlayer: 'sounds/countdown.wav',
      _countdownStartPlayer: 'sounds/countdown_start.wav',
    };
    unawaited(ensureInitialized());
  }

  Future<void> ensureInitialized() {
    if (_isInitialized) {
      return Future<void>.value();
    }
    final inFlight = _initFuture;
    if (inFlight != null) {
      return inFlight;
    }
    final future = _initAudioContext();
    _initFuture = future;
    return future;
  }

  Future<void> _initAudioContext() async {
    try {
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
        if (!kIsWeb) {
          await player.setPlayerMode(PlayerMode.lowLatency);
        }
      }

      await _correctPlayer.setVolume(_volCorrect);
      await _wrongPlayer.setVolume(_volWrong);
      await _startPlayer.setVolume(_volStart);
      await _endPlayer.setVolume(_volEnd);
      await _countdownPlayer.setVolume(_volCountdown);
      await _countdownStartPlayer.setVolume(_volCountdownStart);

      // Preload critical in-game sounds first and delay the rest.
      await _preloadCoreSounds();
      _scheduleSecondaryPreload();

      _isInitialized = true;

      if (kDebugMode) {
        debugPrint('🔊 SoundService: Mit gestuftem Vorladen initialisiert');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ SoundService-Initialisierungsfehler: $e');
      }
    } finally {
      _initFuture = null;
    }
  }

  Future<void> _preparePlayerSource(AudioPlayer player) async {
    if (_preparedSources.contains(player)) {
      return;
    }
    final asset = _playerAssets[player];
    if (asset == null) {
      return;
    }
    await player.setSource(AssetSource(asset));
    _preparedSources.add(player);
  }

  Future<void> _preloadCoreSounds() async {
    await Future.wait([
      _preparePlayerSource(_correctPlayer),
      _preparePlayerSource(_wrongPlayer),
      _preparePlayerSource(_startPlayer),
    ]);
    if (kDebugMode) {
      debugPrint('✅ Kernsounds vorgeladen');
    }
  }

  void _scheduleSecondaryPreload() {
    Future<void>.delayed(const Duration(milliseconds: 1500), () async {
      try {
        await Future.wait([
          _preparePlayerSource(_endPlayer),
          _preparePlayerSource(_countdownPlayer),
          _preparePlayerSource(_countdownStartPlayer),
        ]);
        if (kDebugMode) {
          debugPrint('✅ Zusätzliche Sounds vorgeladen');
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ Fehler beim zusätzlichen Vorladen: $e');
        }
      }
    });
  }

  /// Call this from a user gesture (e.g. button click) to unlock audio on Web
  Future<void> unlock() async {
    await ensureInitialized();
    if (kIsWeb) {
      try {
        await _preparePlayerSource(_startPlayer);
        await _startPlayer.setVolume(0.01);
        await _startPlayer.resume();
        await Future.delayed(const Duration(milliseconds: 100));
        await _startPlayer.stop();
        await _startPlayer.setVolume(_volStart);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Freischaltfehler: $e');
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
    if (_isMuted) return;
    await ensureInitialized();
    if (!_isInitialized) return;

    try {
      await _preparePlayerSource(player);
      await player.stop();
      await player.seek(Duration.zero);
      await player.resume();

      if (kDebugMode) {
        debugPrint('🔊 Spiele ab: $soundName');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Fehler beim Abspielen von $soundName: $e');
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
      debugPrint('🔊 SoundService freigegeben');
    }
  }
}
