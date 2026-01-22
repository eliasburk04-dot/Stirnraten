import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../services/sound_service.dart';
import '../services/custom_word_storage.dart';
import '../engine/stirnraten_engine.dart';
import '../utils/sensor_helper.dart';
import '../utils/effects_quality.dart';
import '../data/words.dart';
import '../widgets/glass_widgets.dart';

const Color _categoryPrimary = Color(0xFF21D4EA);
const Color _categoryBackgroundTop = Color(0xFFFFE277);
const Color _categoryBackgroundMid = Color(0xFFFFB866);
const Color _categoryBackgroundBottom = Color(0xFFF25B8F);
const Color _categorySurface = Color(0xFFFBE6D4);
const Color _categoryGlass = Color(0xB3FFFFFF);
const Color _categoryBorder = Color(0x8CFFFFFF);
const Color _categoryText = Color(0xFF1E293B);
const Color _categoryMuted = Color(0xFF3B4A5A);
const Color _categoryModeGlass = Color(0x66141A26);
const double _categoryCardRadius = 44;

String _gameModeLabel(GameMode mode) {
  switch (mode) {
    case GameMode.classic:
      return 'Klassisch';
    case GameMode.suddenDeath:
      return 'Sudden Death';
    case GameMode.hardcore:
      return 'Hardcore';
    case GameMode.drinking:
      return 'Trinkspiel';
  }
}

Color _gameModeAccent(GameMode mode) {
  switch (mode) {
    case GameMode.classic:
      return _categoryPrimary;
    case GameMode.suddenDeath:
      return const Color(0xFFEF4444);
    case GameMode.hardcore:
      return const Color(0xFF06B6D4);
    case GameMode.drinking:
      return const Color(0xFF4ADE80);
  }
}

const double _tiltNeutralZoneDeg = 10;
const double _tiltTriggerDeg = 25;
const int _tiltHoldMs = 200;
const int _tiltCooldownMs = 900;
const int _tiltCalibrationMs = 1000;

enum _TiltPhase { idle, calibrating, activeWord, triggered, cooldown }
enum _TiltAction { correct, pass }

class _TiltDetector {
  _TiltDetector({
    required this.neutralZoneDeg,
    required this.triggerDeg,
    required this.holdMs,
    required this.cooldownMs,
    required this.calibrationMs,
  });

  final double neutralZoneDeg;
  final double triggerDeg;
  final int holdMs;
  final int cooldownMs;
  final int calibrationMs;

  _TiltPhase _phase = _TiltPhase.idle;
  bool _requiresNeutral = true;
  double _baselinePitch = 0.0;
  int _calibrationStartMs = 0;
  final List<double> _calibrationSamples = <double>[];
  int? _forwardHoldStartMs;
  int? _backwardHoldStartMs;
  int _cooldownUntilMs = 0;

  _TiltPhase get phase => _phase;
  bool get isCalibrating => _phase == _TiltPhase.calibrating;
  double get baselinePitch => _baselinePitch;

  void start(int nowMs) {
    _phase = _TiltPhase.calibrating;
    _requiresNeutral = true;
    _baselinePitch = 0.0;
    _calibrationStartMs = nowMs;
    _calibrationSamples.clear();
    _forwardHoldStartMs = null;
    _backwardHoldStartMs = null;
    _cooldownUntilMs = 0;
  }

  void stop() {
    _phase = _TiltPhase.idle;
    _requiresNeutral = true;
    _baselinePitch = 0.0;
    _calibrationSamples.clear();
    _forwardHoldStartMs = null;
    _backwardHoldStartMs = null;
    _cooldownUntilMs = 0;
  }

  _TiltAction? update(
    double pitchDeg,
    int nowMs, {
    required bool allowTrigger,
  }) {
    if (_phase == _TiltPhase.idle) {
      return null;
    }

    if (_phase == _TiltPhase.calibrating) {
      _calibrationSamples.add(pitchDeg);
      if (nowMs - _calibrationStartMs >= calibrationMs) {
        _finishCalibration();
      }
      return null;
    }

    if (_phase == _TiltPhase.triggered && nowMs < _cooldownUntilMs) {
      _phase = _TiltPhase.cooldown;
    }

    if (nowMs < _cooldownUntilMs) {
      return null;
    }

    final delta = pitchDeg - _baselinePitch;

    if (delta.abs() <= neutralZoneDeg) {
      _requiresNeutral = false;
      _forwardHoldStartMs = null;
      _backwardHoldStartMs = null;
      if (_phase == _TiltPhase.cooldown || _phase == _TiltPhase.triggered) {
        _phase = _TiltPhase.activeWord;
      }
      return null;
    }

    if (_requiresNeutral) {
      return null;
    }

    if (delta >= triggerDeg) {
      _forwardHoldStartMs ??= nowMs;
      if (nowMs - (_forwardHoldStartMs ?? nowMs) >= holdMs) {
        return _registerAction(_TiltAction.correct, nowMs, allowTrigger);
      }
    } else if (delta <= -triggerDeg) {
      _backwardHoldStartMs ??= nowMs;
      if (nowMs - (_backwardHoldStartMs ?? nowMs) >= holdMs) {
        return _registerAction(_TiltAction.pass, nowMs, allowTrigger);
      }
    } else {
      _forwardHoldStartMs = null;
      _backwardHoldStartMs = null;
    }

    return null;
  }

  void _finishCalibration() {
    if (_calibrationSamples.isNotEmpty) {
      final sum = _calibrationSamples.reduce((value, element) => value + element);
      _baselinePitch = sum / _calibrationSamples.length;
    }
    _phase = _TiltPhase.activeWord;
    _requiresNeutral = true;
  }

  _TiltAction? _registerAction(_TiltAction action, int nowMs, bool allowTrigger) {
    _phase = _TiltPhase.triggered;
    _cooldownUntilMs = nowMs + cooldownMs;
    _requiresNeutral = true;
    _forwardHoldStartMs = null;
    _backwardHoldStartMs = null;
    return allowTrigger ? action : null;
  }
}

class StirnratenScreen extends StatefulWidget {
  const StirnratenScreen({super.key});

  @override
  State<StirnratenScreen> createState() => _StirnratenScreenState();
}

class _StirnratenScreenState extends State<StirnratenScreen> {
  final CustomWordStorage _customWordStorage = CustomWordStorage();
  final StirnratenEngine _engine = StirnratenEngine();
  final Set<StirnratenCategory> _selectedCategories = <StirnratenCategory>{};
  bool _showSettingsPanel = false;
  Timer? _gameTimer;
  Timer? _countdownTimer;
  
  // Sensor handling
  final _tiltDetector = _TiltDetector(
    neutralZoneDeg: _tiltNeutralZoneDeg,
    triggerDeg: _tiltTriggerDeg,
    holdMs: _tiltHoldMs,
    cooldownMs: _tiltCooldownMs,
    calibrationMs: _tiltCalibrationMs,
  );
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  bool _canSkip = true;
  DateTime _lastSensorProcessing = DateTime.now();
  static const Duration _sensorThrottle = Duration(milliseconds: 50);
  bool _sensorPermissionGranted = true;
  bool _showFallbackButtons = false;
  bool _receivedSensorEvent = false;
  Timer? _sensorAvailabilityTimer;
  double _lastPitchDeg = 0.0;
  bool _webTiltPermissionRequired = false;
  bool _webTiltPermissionGranted = false;
  bool _webTiltEnabled = false;
  bool _webTiltPermissionDenied = false;
  
  // Feedback
  Color? _feedbackColor;
  String? _feedbackMessage;
  Timer? _feedbackTimer;
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  String _searchQuery = '';
  List<_CategoryCardData> _categoryItems = [];
  List<CustomWordList> _customWordLists = [];

  GameSnapshot get _snapshot => _engine.snapshot;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode()
      ..addListener(() {
        if (mounted) {
          setState(() {});
        }
      });
    _categoryItems = _buildCategoryItems();
    _loadCustomWordLists();
    if (kIsWeb) {
      _webTiltPermissionRequired = isTiltPermissionRequired();
      _webTiltPermissionGranted = !_webTiltPermissionRequired;
    }
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _countdownTimer?.cancel();
    _feedbackTimer?.cancel();
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;
    _sensorAvailabilityTimer?.cancel();
    _tiltDetector.stop();
    
    if (kIsWeb) {
      stopWebTiltDetection();
    }
    
    if (kDebugMode) {
      debugPrint('🎮 Stirnraten: Sensors cleaned up');
    }
    
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _openCustomWordsScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CustomWordsScreen(
          storage: _customWordStorage,
          onPlay: (list) async {
            await _customWordStorage.markPlayed(list.id);
            if (context.mounted) {
              _startCountdownWithWords(list.words);
            }
          },
        ),
      ),
    );
    await _loadCustomWordLists();
  }

  void _toggleCategory(StirnratenCategory category) {
    setState(() {
      if (_selectedCategories.contains(category)) {
        _selectedCategories.remove(category);
      } else {
        _selectedCategories.add(category);
      }
    });
  }

  void _startSelectedCategories() {
    if (_selectedCategories.isEmpty) return;
    final words = _selectedCategories
        .expand((category) => StirnratenData.getWords(category))
        .toList();
    if (words.isEmpty) return;
    _startCountdownWithWords(words);
  }

  void _startCountdownWithWords(List<String> words) async {
    // Unlock audio context on user interaction
    context.read<SoundService>().unlock();

    // Request sensor permission (iOS/Android only)
    if (kIsWeb) {
      _webTiltEnabled = false;
      _webTiltPermissionDenied = false;
    } else {
      _sensorPermissionGranted = await requestSensorPermission();
    }

    // Force landscape for the game
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    setState(() {
      _showSettingsPanel = false;
      _engine.startCountdown(words);
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final shouldStart = _engine.tickCountdown();
      if (!shouldStart) {
        setState(() {});
      } else {
        timer.cancel();
        _startGame();
      }
    });
  }

  void _startGame() {
    if (kDebugMode) {
      debugPrint('🎮 Stirnraten: Game starting...');
    }
    
    setState(() {
      _engine.startGame();
      _feedbackColor = null; // Reset any lingering feedback
      _showFallbackButtons = !kIsWeb && !_sensorPermissionGranted;
      if (kIsWeb) {
        _webTiltEnabled = _webTiltPermissionGranted;
      }
    });
    if (_snapshot.state == StirnratenGameState.result) {
      _endGame();
      return;
    }
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (kIsWeb) {
      _tiltDetector.stop();
    } else {
      _tiltDetector.start(nowMs);
    }
    _receivedSensorEvent = false;
    _sensorAvailabilityTimer?.cancel();
    if (!kIsWeb) {
      _sensorAvailabilityTimer = Timer(
        const Duration(milliseconds: 1200),
        _checkSensorAvailability,
      );
    }

    context.read<SoundService>().playStart();
    _startTimer();
    _startSensors();

    if (kDebugMode) {
      debugPrint('✅ Stirnraten: Game started successfully');
    }
  }

  void _startTimer() {
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final shouldEnd = _engine.tickTimer();
      if (shouldEnd) {
        _endGame();
      } else {
        setState(() {});
      }
    });
  }

  void _startSensors() {
    // Cancel existing subscription if any
    _accelerometerSubscription?.cancel();

    if (kDebugMode) {
      debugPrint('🎮 Stirnraten: Starting sensor listeners...');
      if (!kIsWeb) {
        try {
          debugPrint('📱 Platform: ${defaultTargetPlatform.name}');
        } catch (e) {
          debugPrint('⚠️ Platform detection failed: $e');
        }
      }
    }
    
    if (kIsWeb) {
      if (_webTiltPermissionGranted) {
        startWebTiltDetection(_handleCorrect, _handlePass);
      } else if (kDebugMode) {
        debugPrint('🌐 Web tilt awaiting permission');
      }
      return;
    }

    // Mobile: Use Dart sensor stream
    if (kDebugMode) {
      debugPrint('📱 Using Dart sensor stream for Mobile');
    }
    _accelerometerSubscription = accelerometerEventStream().listen(
      (AccelerometerEvent event) {
        _processSensorData(event.x, event.y, event.z);
      },
      onError: (error) {
        if (kDebugMode) {
          print('⚠️ Sensor error: $error');
        }
      },
      cancelOnError: false,
    );
    
    if (kDebugMode) {
      debugPrint('✅ Sensor listeners activated');
    }
  }

  Future<void> _enableWebTilt() async {
    final granted = await requestSensorPermission();
    if (!mounted) return;
    if (granted && _snapshot.state == StirnratenGameState.playing) {
      startWebTiltDetection(_handleCorrect, _handlePass);
    }
    setState(() {
      _webTiltPermissionGranted = granted;
      _webTiltPermissionDenied = !granted;
      _webTiltEnabled = granted;
    });
  }

  void _processSensorData(double x, double y, double z) {
    if (_snapshot.state != StirnratenGameState.playing) return;
    _receivedSensorEvent = true;

    // Throttle: Process sensor data max every 50ms
    final now = DateTime.now();
    if (now.difference(_lastSensorProcessing) < _sensorThrottle) return;
    _lastSensorProcessing = now;

    final pitch = _computePitchDegrees(x, y, z);
    _lastPitchDeg = pitch;

    final action = _tiltDetector.update(
      pitch,
      now.millisecondsSinceEpoch,
      allowTrigger: _canSkip,
    );

    if (kDebugMode && now.millisecondsSinceEpoch % 500 < 50) {
      debugPrint(
        'Pitch: ${pitch.toStringAsFixed(1)} deg '
        'Baseline: ${_tiltDetector.baselinePitch.toStringAsFixed(1)} deg '
        'Phase: ${_tiltDetector.phase}',
      );
    }

    if (action == _TiltAction.correct) {
      _handleCorrect();
    } else if (action == _TiltAction.pass) {
      _handlePass();
    }
  }

  double _computePitchDegrees(double x, double y, double z) {
    final norm = math.sqrt(x * x + y * y + z * z);
    if (norm == 0) return 0.0;
    final ny = y / norm;
    final nz = z / norm;
    var pitch = math.atan2(ny, nz) * 180 / math.pi;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      pitch = -pitch;
    }
    return pitch;
  }

  void _checkSensorAvailability() {
    if (kIsWeb) return;
    if (!mounted || _snapshot.state != StirnratenGameState.playing) return;
    if (_receivedSensorEvent) return;
    final webAvailable = kIsWeb ? getWebSensorAvailable() : _receivedSensorEvent;
    final sensorAvailable = _sensorPermissionGranted && webAvailable;
    if (!sensorAvailable && !_showFallbackButtons) {
      setState(() => _showFallbackButtons = true);
    }
  }

  void _nextWord() {
    final advanced = _engine.advanceWord();
    if (!advanced) {
      _endGame();
      return;
    }
    setState(() {});
  }

  void _handleCorrect() {
    _handleGameAction(GameAction.correct);
  }

  void _handlePass() {
    _handleGameAction(GameAction.skip);
  }

  void _handleGameAction(GameAction action) {
    if (_snapshot.state != StirnratenGameState.playing || !_canSkip) return;
    if (_tiltDetector.isCalibrating && !_showFallbackButtons) return;
    _canSkip = false;

    switch (_snapshot.activeMode) {
      case GameMode.classic:
        if (action == GameAction.correct) {
          _applyCorrectAction();
        } else {
          _applyClassicSkip();
        }
        break;
      case GameMode.suddenDeath:
        if (action == GameAction.correct) {
          _applyCorrectAction();
        } else {
          _applySuddenDeathSkip();
        }
        break;
      case GameMode.hardcore:
        if (action == GameAction.correct) {
          _applyCorrectAction();
        } else {
          _applyHardcoreSkip();
        }
        break;
      case GameMode.drinking:
        if (action == GameAction.correct) {
          _applyCorrectAction();
        } else {
          _applyDrinkingSkip();
        }
        break;
    }
  }

  void _applyCorrectAction() {
    if (kDebugMode) {
      debugPrint('Correct action triggered');
    }

    _engine.applyAction(GameAction.correct);
    setState(() {});

    HapticFeedback.heavyImpact();
    context.read<SoundService>().playCorrect().then((_) {
      if (kDebugMode) {
        debugPrint('Correct sound played');
      }
    }).catchError((e) {
      if (kDebugMode) {
        debugPrint('Sound error: $e');
      }
    });

    _showFeedback(
      const Color(0xDD10B981),
      onFinished: () {
        _nextWord();
        _canSkip = true;
      },
    );
  }

  void _applyClassicSkip() {
    if (kDebugMode) {
      debugPrint('Skip action triggered');
    }

    _engine.applyAction(GameAction.skip);
    setState(() {});

    context.read<SoundService>().playWrong().then((_) {
      if (kDebugMode) {
        debugPrint('Wrong sound played');
      }
    }).catchError((e) {
      if (kDebugMode) {
        debugPrint('Sound error: $e');
      }
    });

    _showFeedback(
      const Color(0xCCEF4444),
      onFinished: () {
        _nextWord();
        _canSkip = true;
      },
    );
  }

  void _applySuddenDeathSkip() {
    if (kDebugMode) {
      debugPrint('Sudden Death fail');
    }

    _engine.applyAction(GameAction.skip);
    setState(() {});

    HapticFeedback.mediumImpact();
    context.read<SoundService>().playWrong();

    _showFeedback(
      const Color(0xCCEF4444),
      label: 'Game Over',
      durationMs: 650,
      onFinished: _endGame,
    );
  }

  void _applyHardcoreSkip() {
    if (kDebugMode) {
      debugPrint('Hardcore skip penalty');
    }

    final outcome = _engine.applyAction(GameAction.skip);
    setState(() {});

    HapticFeedback.mediumImpact();
    context.read<SoundService>().playWrong();

    _showFeedback(
      const Color(0xCC06B6D4),
      label: '-${hardcoreSkipPenaltySeconds}s',
      durationMs: 450,
      onFinished: () {
        if (outcome.outOfTime) {
          _endGame();
        } else {
          _nextWord();
          _canSkip = true;
        }
      },
    );
  }

  void _applyDrinkingSkip() {
    if (kDebugMode) {
      debugPrint('Drinking mode skip');
    }

    _engine.applyAction(GameAction.skip);
    setState(() {});

    HapticFeedback.lightImpact();
    context.read<SoundService>().playWrong();

    _showFeedback(
      const Color(0xCC06B6D4),
      label: 'Trink ${drinkingSkipSips} Schluck',
      durationMs: 550,
      onFinished: () {
        _nextWord();
        _canSkip = true;
      },
    );
  }
  
  void _showFeedback(
    Color color, {
    String? label,
    int durationMs = 400,
    VoidCallback? onFinished,
  }) {
    setState(() {
      _feedbackColor = color;
      _feedbackMessage = label;
    });
    _feedbackTimer?.cancel();
    _feedbackTimer = Timer(Duration(milliseconds: durationMs), () {
      if (mounted) {
        setState(() {
          _feedbackColor = null;
          _feedbackMessage = null;
        });
        onFinished?.call();
      }
    });
  }

  void _endGame() {
    _gameTimer?.cancel();
    _accelerometerSubscription?.cancel();
    _sensorAvailabilityTimer?.cancel();
    _tiltDetector.stop();
    
    if (kIsWeb) {
      stopWebTiltDetection();
    }
    
    context.read<SoundService>().playEnd();
    
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    setState(() {
      _engine.endGame();
      _webTiltEnabled = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A12),
      resizeToAvoidBottomInset: false,
      body: ModernBackground(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    switch (_snapshot.state) {
      case StirnratenGameState.setup:
        return _buildSetup();
      case StirnratenGameState.countdown:
        return _buildCountdown();
      case StirnratenGameState.playing:
        return _buildGame();
      case StirnratenGameState.result:
        return _buildResult();
    }
  }
  
  Widget _buildCountdown() {
    return Center(
      child: GlassCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${_snapshot.countdown}',
              style: const TextStyle(
                fontSize: 120,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -2,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Handy an die Stirn!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: Color(0xB3FFFFFF),
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_CategoryCardData> _buildCategoryItems() {
    return StirnratenCategory.values.map((category) {
      final title = StirnratenData.categoryNames[category] ?? category.name;
      final wordCount = StirnratenData.getWords(category).length;
      final subtitle = category == StirnratenCategory.ownWords
          ? (_customWordLists.isEmpty
              ? 'Eigene Listen erstellen'
              : '${_customWordLists.length} Listen')
          : '';
      final tags = wordCount >= 120 ? const ['POPULAR'] : const <String>[];
      final difficulty = wordCount >= 140 ? 'HARD' : null;
      final progress = wordCount >= 140 ? 0.75 : null;
      return _CategoryCardData(
        category: category,
        title: title,
        subtitle: subtitle,
        icon: StirnratenData.categoryIcons[category],
        accentColor: _getCategoryGradient(category).first,
        tags: tags,
        isNsfw: false,
        difficulty: difficulty,
        progress: progress,
        isOwnWords: category == StirnratenCategory.ownWords,
      );
    }).toList();
  }

  List<_CategoryCardData> get _filteredCategories {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return _categoryItems;
    }
    return _categoryItems.where((item) {
      final haystack = <String>[
        item.title,
        item.subtitle,
        ...item.tags,
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  Widget _buildSetup() {
    final filteredCategories = _filteredCategories;
    final selectedCount = _selectedCategories.length;
    const bottomBarHeight = 112.0;
    final topInset = MediaQuery.of(context).padding.top;

    return DefaultTextStyle(
      style: GoogleFonts.nunito(
        color: _categoryText,
        fontWeight: FontWeight.w600,
      ),
      child: Stack(
        children: [
          const _CategoryBackground(),
          SafeArea(
            child: ScrollConfiguration(
              behavior: const _NoScrollbarBehavior(),
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _CategoryHeaderDelegate(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      isFocused: _searchFocusNode.hasFocus,
                      onBack: () => Navigator.pop(context),
                      onSettings: _toggleSettingsPanel,
                      onQueryChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      24,
                      16,
                      24,
                      bottomBarHeight,
                    ),
                    sliver: SliverMasonryGrid.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childCount: filteredCategories.length,
                      itemBuilder: (context, index) {
                        final item = filteredCategories[index];
                        final isSelected =
                            _selectedCategories.contains(item.category);
                        return _CategoryCard(
                          data: item,
                          isSelected: isSelected,
                          onTap: () {
                            if (item.isOwnWords) {
                              _openCustomWordsScreen();
                            } else {
                              _toggleCategory(item.category);
                            }
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          _BottomActionBar(
            selectedCount: selectedCount,
            onPressed: selectedCount == 0 ? null : _startSelectedCategories,
          ),
          if (_showSettingsPanel)
            Positioned.fill(
              child: GestureDetector(
                onTap: _closeSettingsPanel,
                behavior: HitTestBehavior.translucent,
                child: const SizedBox.expand(),
              ),
            ),
          if (_showSettingsPanel)
            Positioned(
              top: topInset + 88,
              right: 20,
              child: _SettingsPanel(
                selectedTime: _snapshot.selectedTime,
                selectedMode: _snapshot.selectedMode,
                onTimeChanged: (value) {
                  setState(() => _engine.setSelectedTime(value));
                },
                onModeChanged: (mode) {
                  setState(() => _engine.setSelectedMode(mode));
                },
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _loadCustomWordLists() async {
    final lists = await _customWordStorage.getLists();
    if (!mounted) return;
    setState(() {
      _customWordLists = lists;
      _categoryItems = _buildCategoryItems();
    });
  }

  void _toggleSettingsPanel() {
    setState(() => _showSettingsPanel = !_showSettingsPanel);
  }

  void _closeSettingsPanel() {
    if (!_showSettingsPanel) return;
    setState(() => _showSettingsPanel = false);
  }

  List<Color> _getCategoryGradient(StirnratenCategory category) {
    switch (category) {
      case StirnratenCategory.anime:
        return [const Color(0xFFEF4444), const Color(0xFFEC4899)];
      case StirnratenCategory.starWars:
        return [const Color(0xFF0EA5E9), const Color(0xFF6366F1)];
      case StirnratenCategory.films:
        return [const Color(0xFF10B981), const Color(0xFF059669)];
      case StirnratenCategory.series:
        return [const Color(0xFF3B82F6), const Color(0xFF2563EB)];
      case StirnratenCategory.music:
        return [const Color(0xFF9B59B6), const Color(0xFF8B5CF6)];
      case StirnratenCategory.celebrities:
        return [const Color(0xFFE67E22), const Color(0xFFD97706)];
      case StirnratenCategory.animals:
        return [const Color(0xFF16A085), const Color(0xFF14B8A6)];
      case StirnratenCategory.food:
        return [const Color(0xFFE74C3C), const Color(0xFFDC2626)];
      case StirnratenCategory.places:
        return [const Color(0xFF64748B), const Color(0xFF475569)];
      case StirnratenCategory.jobs:
        return [const Color(0xFF7F8C8D), const Color(0xFF6B7280)];
      case StirnratenCategory.tech:
        return [const Color(0xFF06B6D4), const Color(0xFF0891B2)];
      case StirnratenCategory.sports:
        return [const Color(0xFF22C55E), const Color(0xFF16A34A)];
      case StirnratenCategory.kids:
        return [const Color(0xFF22D3EE), const Color(0xFF38BDF8)];
      case StirnratenCategory.mythology:
        return [const Color(0xFF8E44AD), const Color(0xFF7C3AED)];
      case StirnratenCategory.plants:
        return [const Color(0xFF10B981), const Color(0xFF10B981)];
      case StirnratenCategory.videogames:
        return [const Color(0xFF8B5CF6), const Color(0xFF6366F1)];
      case StirnratenCategory.superheroes:
        return [const Color(0xFFEF4444), const Color(0xFF3B82F6)];
      case StirnratenCategory.disney:
        return [const Color(0xFF3B82F6), const Color(0xFF60A5FA)];
      case StirnratenCategory.youtubers:
        return [const Color(0xFFFF0000), const Color(0xFFFF4444)];
      case StirnratenCategory.brands:
        return [const Color(0xFF1F2937), const Color(0xFF4B5563)];
      case StirnratenCategory.nineties:
        return [const Color(0xFFEC4899), const Color(0xFF8B5CF6)];
      case StirnratenCategory.twoThousands:
        return [const Color(0xFF06B6D4), const Color(0xFF3B82F6)];
      case StirnratenCategory.history:
        return [const Color(0xFFD97706), const Color(0xFFB45309)];
      case StirnratenCategory.pantomime:
        return [const Color(0xFF10B981), const Color(0xFF34D399)];
      case StirnratenCategory.noises:
        return [const Color(0xFF06B6D4), const Color(0xFF22D3EE)];
      case StirnratenCategory.household:
        return [const Color(0xFF6B7280), const Color(0xFF9CA3AF)];
      case StirnratenCategory.bodyParts:
        return [const Color(0xFFEC4899), const Color(0xFFF472B6)];
      case StirnratenCategory.books:
        return [const Color(0xFF8B5CF6), const Color(0xFFA78BFA)];
      case StirnratenCategory.cities:
        return [const Color(0xFF3B82F6), const Color(0xFF60A5FA)];
      case StirnratenCategory.festivals:
        return [const Color(0xFF3B82F6), const Color(0xFF60A5FA)];
      case StirnratenCategory.feelings:
        return [const Color(0xFFEF4444), const Color(0xFFF87171)];
      case StirnratenCategory.ownWords:
        return [const Color(0xFF8B5CF6), const Color(0xFFEC4899)];
    }
  }

  Widget _buildGame() {
    final effects = EffectsConfig.of(context);
    final timerBlur = effects.blur(high: 6, medium: 4, low: 0);
    return Stack(
      children: [
        Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF1E293B),
                Color(0xFF0F172A),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        
        if (!_showFallbackButtons)
          // Touch controls - Links überspringen, Rechts richtig
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _handlePass,
                  behavior: HitTestBehavior.translucent,
                  child: Container(
                    color: Colors.transparent,
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: _handleCorrect,
                  behavior: HitTestBehavior.translucent,
                  child: Container(
                    color: Colors.transparent,
                  ),
                ),
              ),
            ],
          ),

        Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(
              _snapshot.currentWord,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 60,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),

        Positioned(
          top: 40,
          right: 28,
          child: RepaintBoundary(
            child: GlassBackdrop(
              blurSigma: timerBlur,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(20),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withAlpha(40),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  '${_snapshot.timeLeft}',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ),
          ),
        ),

        Positioned(
          top: 40,
          left: 28,
          child: _ModeBadge(mode: _snapshot.activeMode),
        ),

        if (kIsWeb && _webTiltEnabled)
          const Positioned(
            top: 96,
            right: 28,
            child: _TiltStatusBadge(),
          ),

        if (kIsWeb && !_webTiltPermissionGranted && _webTiltPermissionRequired)
          Positioned(
            bottom: 92,
            left: 0,
            right: 0,
            child: Column(
              children: [
                _TiltEnableButton(
                  onTap: _enableWebTilt,
                ),
                if (_webTiltPermissionDenied)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      'Tilt nicht verf\u00fcgbar',
                      style: TextStyle(
                        color: Color(0x80FFFFFF),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),

        Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Text(
            kIsWeb
                ? 'Tippen zum Antworten'
                : (_showFallbackButtons
                    ? 'Sensor nicht verfuegbar'
                    : 'Kippen zum Antworten'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0x80FFFFFF),
              fontSize: 14,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
        ),

        if (kDebugMode && !kIsWeb)
          Positioned(
            left: 16,
            bottom: _showFallbackButtons ? 160 : 80,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'pitch ${_lastPitchDeg.toStringAsFixed(1)} deg\\n'
                'state ${_tiltDetector.phase}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  height: 1.2,
                ),
              ),
            ),
          ),

        // Feedback Overlay - MUSS ZULETZT IM STACK SEIN für höchste Z-Order
        if (_feedbackColor != null)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: 0.85,
                duration: const Duration(milliseconds: 150),
                child: Container(
                  color: _feedbackColor!,
                  child: _feedbackMessage == null
                      ? null
                      : Center(
                          child: Text(
                            _feedbackMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildResult() {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Zeit abgelaufen!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '${_snapshot.score}',
                style: const TextStyle(
                  fontSize: 72,
                  fontWeight: FontWeight.w800,
                  color: _categoryPrimary,
                  letterSpacing: -2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _snapshot.score == 1 ? 'Punkt' : 'Punkte',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withAlpha(140),
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 48),
              if (_snapshot.results.isNotEmpty)
                GlassCard(
                  child: Column(
                    children: [
                      ...List.generate(
                        _snapshot.results.length.clamp(0, 10),
                        (index) {
                          final result = _snapshot.results[index];
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: index < _snapshot.results.length - 1 ? 16 : 0,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                result.correct
                                    ? Icons.check_circle
                                    : Icons.cancel,
                                color: result.correct
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFEF4444),
                                size: 24,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  result.word,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      if (_snapshot.results.length > 10) ...[
                        const SizedBox(height: 16),
                        Text(
                          '+ ${_snapshot.results.length - 10} weitere',
                          style: TextStyle(
                            color: Colors.white.withAlpha(128),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 32),
              GlassButton(
                text: 'Nochmal spielen',
                isFullWidth: true,
                gradientColors: const [
                  Color(0xFF3B82F6),
                  Color(0xFF22D3EE),
                ],
                onPressed: () {
                  setState(() {
                    _engine.resetToSetup();
                  });
                },
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Zurück zum Hauptmenü',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                            color: Color(0x8CFFFFFF),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryCardData {
  const _CategoryCardData({
    required this.category,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    this.icon,
    this.tags = const <String>[],
    this.isNsfw = false,
    this.difficulty,
    this.progress,
    this.isOwnWords = false,
  });

  final StirnratenCategory category;
  final String title;
  final String subtitle;
  final Color? accentColor;
  final IconData? icon;
  final List<String> tags;
  final bool isNsfw;
  final String? difficulty;
  final double? progress;
  final bool isOwnWords;
}

class _CategoryCard extends StatefulWidget {
  final _CategoryCardData data;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.data,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) {
      setState(() => _pressed = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final effects = EffectsConfig.of(context);
    final blurSigma = effects.blur(high: 18, medium: 0, low: 0);
    final glowBlur = effects.shadowBlur(high: 26, medium: 20, low: 12);
    final accent = widget.data.accentColor ?? _categoryPrimary;
    final glowAlpha = effects.shadowAlpha(
      high: widget.isSelected ? 0.28 : 0.12,
      medium: widget.isSelected ? 0.2 : 0.08,
      low: 0,
    );
    final borderColor =
        widget.isSelected ? accent.withValues(alpha: 0.8) : _categoryBorder;
    final scale = _pressed ? 0.96 : (widget.isSelected ? 1.02 : 1.0);
    final showGlow = widget.isSelected;

    return RepaintBoundary(
      child: GestureDetector(
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          child: GlassBackdrop(
            blurSigma: blurSigma,
            borderRadius: BorderRadius.circular(_categoryCardRadius),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _categoryGlass,
                borderRadius: BorderRadius.circular(_categoryCardRadius),
                border: Border.all(
                  color: borderColor,
                  width: widget.isSelected ? 2 : 1,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.7),
                    Colors.white.withValues(alpha: 0.45),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: glowBlur,
                    offset: const Offset(0, 12),
                  ),
                  if (showGlow)
                    BoxShadow(
                      color: accent.withValues(alpha: glowAlpha),
                      blurRadius: glowBlur + 6,
                      offset: const Offset(0, 10),
                    ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _CategoryIconBadge(
                        icon: widget.data.icon,
                        accent: accent,
                      ),
                      const Spacer(),
                      if (widget.data.isNsfw || widget.isSelected)
                        Wrap(
                          spacing: 6,
                          children: [
                            if (widget.data.isNsfw)
                              const _CategoryBadge(
                                label: '18+',
                                background: Color(0xFFB91C1C),
                                textColor: Colors.white,
                              ),
                            if (widget.isSelected)
                              const _CategoryBadge(
                                label: 'SELECTED',
                                background: _categoryPrimary,
                                textColor: _categoryText,
                              ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    widget.data.title,
                    style: GoogleFonts.fredoka(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _categoryText,
                      letterSpacing: 0.2,
                    ),
                  ),
                  if (widget.data.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      widget.data.subtitle,
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _categoryMuted.withValues(alpha: 0.75),
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                  if (widget.data.tags.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: widget.data.tags
                          .map(
                            (tag) => _TagChip(
                              label: tag,
                              color: accent,
                            ),
                          )
                          .toList(),
                    ),
                  ],
                  if (widget.data.progress != null ||
                      widget.data.difficulty != null) ...[
                    const SizedBox(height: 12),
                    _CategoryProgress(
                      progress: widget.data.progress,
                      difficulty: widget.data.difficulty,
                      accent: accent,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryIconBadge extends StatelessWidget {
  final IconData? icon;
  final Color accent;

  const _CategoryIconBadge({
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.75),
        shape: BoxShape.circle,
        border: Border.all(
          color: accent.withValues(alpha: 0.55),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.22),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: icon == null
          ? const SizedBox.shrink()
          : Icon(
              icon,
              color: accent,
              size: 24,
            ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  final String label;
  final Color background;
  final Color textColor;

  const _CategoryBadge({
    required this.label,
    required this.background,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.nunito(
          color: textColor,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  final Color color;

  const _TagChip({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withValues(alpha: 0.55),
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.nunito(
          color: _categoryText,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _CategoryProgress extends StatelessWidget {
  final double? progress;
  final String? difficulty;
  final Color accent;

  const _CategoryProgress({
    required this.progress,
    required this.difficulty,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final value = (progress ?? 0.0).clamp(0.0, 1.0);

    return Row(
      children: [
        Expanded(
          child: Container(
            height: 6,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: value,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        accent.withValues(alpha: 0.95),
                        accent.withValues(alpha: 0.55),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (difficulty != null) ...[
          const SizedBox(width: 8),
          Text(
            difficulty!,
            style: GoogleFonts.nunito(
              color: _categoryMuted.withValues(alpha: 0.8),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ],
    );
  }
}

class _BottomActionBar extends StatelessWidget {
  final int selectedCount;
  final VoidCallback? onPressed;

  const _BottomActionBar({
    required this.selectedCount,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        top: false,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                _categoryBackgroundBottom.withValues(alpha: 0.0),
                _categoryBackgroundBottom.withValues(alpha: 0.6),
                _categoryBackgroundBottom,
              ],
            ),
          ),
          child: SizedBox(
            width: double.infinity,
            child: _PrimaryActionButton(
              label: 'Play ($selectedCount Selected)',
              onTap: onPressed,
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryActionButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;

  const _PrimaryActionButton({
    required this.label,
    required this.onTap,
  });

  @override
  State<_PrimaryActionButton> createState() => _PrimaryActionButtonState();
}

class _PrimaryActionButtonState extends State<_PrimaryActionButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) {
      setState(() => _pressed = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final effects = EffectsConfig.of(context);
    final isEnabled = widget.onTap != null;
    final shadowBlur = effects.shadowBlur(high: 24, medium: 18, low: 0);
    final shadowAlpha = effects.shadowAlpha(high: 0.4, medium: 0.28, low: 0);
    final backgroundColor = isEnabled ? _categoryPrimary : _categorySurface;
    final foregroundColor =
        isEnabled ? _categoryText : _categoryMuted.withValues(alpha: 0.7);

    return GestureDetector(
      onTapDown: isEnabled ? (_) => _setPressed(true) : null,
      onTapUp: isEnabled ? (_) => _setPressed(false) : null,
      onTapCancel: isEnabled ? () => _setPressed(false) : null,
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed && isEnabled ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          height: 64,
          width: double.infinity,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(999),
            boxShadow: isEnabled && shadowBlur > 0
                ? [
                    BoxShadow(
                      color: _categoryPrimary.withValues(alpha: shadowAlpha),
                      blurRadius: shadowBlur,
                      offset: const Offset(0, 12),
                    ),
                  ]
                : null,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(
                widget.label,
                textAlign: TextAlign.center,
                style: GoogleFonts.fredoka(
                  color: foregroundColor,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
              Positioned(
                right: 10,
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: _categoryText,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeBadge extends StatelessWidget {
  final GameMode mode;

  const _ModeBadge({required this.mode});

  @override
  Widget build(BuildContext context) {
    final accent = _gameModeAccent(mode);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _categoryModeGlass,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: accent.withValues(alpha: 0.45),
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: accent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _gameModeLabel(mode),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _TiltStatusBadge extends StatelessWidget {
  const _TiltStatusBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.55)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Text(
        'Tilt: an',
        style: GoogleFonts.nunito(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
          color: _categoryText,
        ),
      ),
    );
  }
}

class _TiltEnableButton extends StatefulWidget {
  final VoidCallback onTap;

  const _TiltEnableButton({required this.onTap});

  @override
  State<_TiltEnableButton> createState() => _TiltEnableButtonState();
}

class _TiltEnableButtonState extends State<_TiltEnableButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) {
      setState(() => _pressed = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: Text(
              'Tilt aktivieren',
              style: GoogleFonts.fredoka(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _categoryText,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SegmentedOption<T> {
  final T value;
  final String label;

  const _SegmentedOption({required this.value, required this.label});
}

class _SegmentedControl<T> extends StatelessWidget {
  final List<_SegmentedOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;

  const _SegmentedControl({
    required this.options,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: options.map((option) {
        final selected = option.value == value;
        final backgroundColor = selected
            ? _categoryPrimary
            : Colors.white.withValues(alpha: 0.7);
        final textColor = selected
            ? _categoryText
            : _categoryMuted.withValues(alpha: 0.75);

        return GestureDetector(
          onTap: () => onChanged(option.value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected
                    ? _categoryPrimary
                    : Colors.white.withValues(alpha: 0.5),
              ),
            ),
            child: Text(
              option.label,
              style: GoogleFonts.nunito(
                color: textColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  final int selectedTime;
  final ValueChanged<int> onTimeChanged;
  final GameMode selectedMode;
  final ValueChanged<GameMode> onModeChanged;

  const _SettingsPanel({
    required this.selectedTime,
    required this.onTimeChanged,
    required this.selectedMode,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final effects = EffectsConfig.of(context);
    final blurSigma = effects.blur(high: 18, medium: 0, low: 0);
    final shadowBlur = effects.shadowBlur(high: 22, medium: 16, low: 10);
    const timeOptions = [
      _SegmentedOption<int>(value: 30, label: '30s'),
      _SegmentedOption<int>(value: 60, label: '60s'),
      _SegmentedOption<int>(value: 90, label: '90s'),
      _SegmentedOption<int>(value: 120, label: '120s'),
    ];

    final modeOptions = [
      _SegmentedOption<GameMode>(value: GameMode.classic, label: 'Klassisch'),
      _SegmentedOption<GameMode>(value: GameMode.suddenDeath, label: 'Sudden'),
      _SegmentedOption<GameMode>(value: GameMode.hardcore, label: 'Hardcore'),
      _SegmentedOption<GameMode>(value: GameMode.drinking, label: 'Trinkspiel'),
    ];

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: GlassBackdrop(
        blurSigma: blurSigma,
        borderRadius: BorderRadius.circular(_categoryCardRadius),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _categoryGlass,
            borderRadius: BorderRadius.circular(_categoryCardRadius),
            border: Border.all(color: _categoryBorder, width: 1.2),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.7),
                Colors.white.withValues(alpha: 0.45),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: shadowBlur,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                Text(
                  'Spielzeit',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                    color: _categoryMuted,
                  ),
                ),
                const SizedBox(height: 8),
                _SegmentedControl<int>(
                  options: timeOptions,
                  value: selectedTime,
                  onChanged: onTimeChanged,
                ),
                const SizedBox(height: 12),
                Text(
                  'Modus',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                    color: _categoryMuted,
                  ),
                ),
                const SizedBox(height: 8),
                _SegmentedControl<GameMode>(
                  options: modeOptions,
                  value: selectedMode,
                  onChanged: onModeChanged,
                ),
                if (selectedMode == GameMode.drinking) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Optionaler Party-Modus. Bitte verantwortungsvoll.',
                    style: GoogleFonts.nunito(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _categoryMuted.withValues(alpha: 0.75),
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _SettingsChip(label: 'Skip = $drinkingSkipSips Schluck'),
                      _SettingsChip(label: 'Fehler = $drinkingWrongSips Schluck'),
                    ],
                  ),
                ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsChip extends StatelessWidget {
  final String label;

  const _SettingsChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: GoogleFonts.nunito(
          color: _categoryMuted.withValues(alpha: 0.8),
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _CategoryHeaderDelegate extends SliverPersistentHeaderDelegate {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isFocused;
  final VoidCallback onBack;
  final VoidCallback onSettings;
  final ValueChanged<String> onQueryChanged;

  _CategoryHeaderDelegate({
    required this.controller,
    required this.focusNode,
    required this.isFocused,
    required this.onBack,
    required this.onSettings,
    required this.onQueryChanged,
  });

  @override
  double get minExtent => 128;

  @override
  double get maxExtent => 128;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final showShadow = overlapsContent || shrinkOffset > 0;
    final effects = EffectsConfig.of(context);
    final blurSigma = effects.blur(high: 18, medium: 0, low: 0);
    final shadowBlur = effects.shadowBlur(high: 18, medium: 14, low: 10);
    final header = Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: shadowBlur,
                  offset: const Offset(0, 12),
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          Row(
            children: [
              _IconCircleButton(
                icon: Icons.arrow_back_rounded,
                onTap: onBack,
              ),
              Expanded(
                child: Center(
                  child: Text(
                    'Stirnraten',
                    style: GoogleFonts.fredoka(
                      color: _categoryText,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
              _IconCircleButton(
                icon: Icons.settings_rounded,
                onTap: onSettings,
                isPrimary: true,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SearchField(
            controller: controller,
            focusNode: focusNode,
            onChanged: onQueryChanged,
            isFocused: isFocused,
          ),
        ],
      ),
    );

    return ClipRect(
      child: blurSigma <= 0
          ? header
          : BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: blurSigma,
                sigmaY: blurSigma,
              ),
              child: header,
            ),
    );
  }

  @override
  bool shouldRebuild(covariant _CategoryHeaderDelegate oldDelegate) {
    return oldDelegate.controller != controller ||
        oldDelegate.focusNode != focusNode ||
        oldDelegate.isFocused != isFocused ||
        oldDelegate.onBack != onBack ||
        oldDelegate.onSettings != onSettings ||
        oldDelegate.onQueryChanged != onQueryChanged;
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final bool isFocused;

  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.isFocused,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isFocused ? _categoryPrimary : Colors.white.withValues(alpha: 0.5),
        ),
        boxShadow: isFocused
            ? [
                BoxShadow(
                  color: _categoryPrimary.withValues(alpha: 0.2),
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            color: _categoryMuted.withValues(alpha: 0.6),
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              style: GoogleFonts.nunito(
                color: _categoryText,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: 'Search decks...',
                hintStyle: GoogleFonts.nunito(
                  color: _categoryMuted.withValues(alpha: 0.55),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconCircleButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isPrimary;

  const _IconCircleButton({
    required this.icon,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  State<_IconCircleButton> createState() => _IconCircleButtonState();
}

class _IconCircleButtonState extends State<_IconCircleButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) {
      setState(() => _pressed = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = widget.isPrimary
        ? _categoryPrimary
        : Colors.white.withValues(alpha: 0.75);
    final borderColor = widget.isPrimary
        ? _categoryPrimary
        : Colors.white.withValues(alpha: 0.55);
    final iconColor = widget.isPrimary
        ? _categoryText
        : _categoryText.withValues(alpha: 0.8);
    final scale = _pressed ? 0.94 : 1.0;

    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
              if (widget.isPrimary)
                BoxShadow(
                  color: _categoryPrimary.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
            ],
          ),
          child: Icon(
            widget.icon,
            color: iconColor,
            size: 22,
          ),
        ),
      ),
    );
  }
}

class CustomWordsScreen extends StatefulWidget {
  final CustomWordStorage storage;
  final void Function(CustomWordList list) onPlay;

  const CustomWordsScreen({
    super.key,
    required this.storage,
    required this.onPlay,
  });

  @override
  State<CustomWordsScreen> createState() => _CustomWordsScreenState();
}

class _CustomWordsScreenState extends State<CustomWordsScreen> {
  List<CustomWordList> _lists = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLists();
  }

  Future<void> _loadLists() async {
    final lists = await widget.storage.getLists();
    if (!mounted) return;
    setState(() {
      _lists = lists;
      _loading = false;
    });
  }

  Future<void> _openEditor({CustomWordList? list}) async {
    final result = await Navigator.push<CustomWordList?>(
      context,
      MaterialPageRoute(
        builder: (context) => CustomWordEditorScreen(
          storage: widget.storage,
          list: list,
        ),
      ),
    );
    if (result != null) {
      await _loadLists();
    }
  }

  Future<void> _confirmDelete(CustomWordList list) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Liste löschen'),
        content: Text('"${list.title}" wirklich löschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (shouldDelete == true) {
      await widget.storage.deleteList(list.id);
      await _loadLists();
    }
  }

  Future<void> _playList(CustomWordList list) async {
    await widget.storage.markPlayed(list.id);
    if (!mounted) return;
    Navigator.pop(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onPlay(list);
    });
  }

  @override
  Widget build(BuildContext context) {
    final effects = EffectsConfig.of(context);

    return Scaffold(
      body: Stack(
        children: [
          const _CategoryBackground(),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
                  child: Row(
                    children: [
                      _HeaderIconButton(
                        icon: Icons.arrow_back_rounded,
                        onTap: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Eigene Wörter',
                          style: GoogleFonts.fredoka(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: _categoryText,
                          ),
                        ),
                      ),
                      _PrimaryPillButton(
                        label: 'Neue Liste',
                        icon: Icons.add_rounded,
                        onTap: () => _openEditor(),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                  child: Text(
                    'Erstelle eigene Wortlisten und spiele sie jederzeit wieder.',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _categoryMuted,
                    ),
                  ),
                ),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _lists.isEmpty
                          ? const _EmptyState()
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                              itemCount: _lists.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final list = _lists[index];
                                return _CustomListCard(
                                  list: list,
                                  effects: effects,
                                  onPlay: () => _playList(list),
                                  onEdit: () => _openEditor(list: list),
                                  onDelete: () => _confirmDelete(list),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CustomWordEditorScreen extends StatefulWidget {
  final CustomWordStorage storage;
  final CustomWordList? list;

  const CustomWordEditorScreen({
    super.key,
    required this.storage,
    this.list,
  });

  @override
  State<CustomWordEditorScreen> createState() => _CustomWordEditorScreenState();
}

class _CustomWordEditorScreenState extends State<CustomWordEditorScreen> {
  static const int _minWords = 10;
  static const int _maxWords = 500;

  late final TextEditingController _titleController;
  late final TextEditingController _wordsController;
  int _wordCount = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.list?.title ?? '');
    _wordsController = TextEditingController(
      text: widget.list?.words.join('\n') ?? '',
    );
    _recountWords();
    _wordsController.addListener(_recountWords);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _wordsController.dispose();
    super.dispose();
  }

  void _recountWords() {
    final words = _parseWords(_wordsController.text, cap: _maxWords);
    setState(() {
      _wordCount = words.length;
      if (_error != null && _wordCount >= _minWords) {
        _error = null;
      }
    });
  }

  List<String> _parseWords(String raw, {int? cap}) {
    final parts = raw.replaceAll(',', '\n').split('\n');
    final seen = <String>{};
    final result = <String>[];
    for (final part in parts) {
      final word = part.trim();
      if (word.isEmpty) continue;
      final key = word.toLowerCase();
      if (seen.add(key)) {
        result.add(word);
      }
      if (cap != null && result.length >= cap) break;
    }
    return result;
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final words = _parseWords(_wordsController.text, cap: _maxWords);
    if (title.isEmpty) {
      setState(() => _error = 'Bitte einen Titel angeben.');
      return;
    }
    if (words.length < _minWords) {
      setState(() => _error = 'Mindestens $_minWords Wörter erforderlich.');
      return;
    }

    final now = DateTime.now();
    final list = widget.list == null
        ? widget.storage.buildNewList(title: title, words: words)
        : widget.list!.copyWith(
            title: title,
            words: words,
            updatedAt: now,
          );

    await widget.storage.saveList(list);
    if (!mounted) return;
    Navigator.pop(context, list);
  }

  @override
  Widget build(BuildContext context) {
    final canSave =
        _titleController.text.trim().isNotEmpty && _wordCount >= _minWords;

    return Scaffold(
      body: Stack(
        children: [
          const _CategoryBackground(),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
                  child: Row(
                    children: [
                      _HeaderIconButton(
                        icon: Icons.close_rounded,
                        onTap: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.list == null ? 'Neue Liste' : 'Liste bearbeiten',
                          style: GoogleFonts.fredoka(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: _categoryText,
                          ),
                        ),
                      ),
                      _PrimaryPillButton(
                        label: 'Speichern',
                        icon: Icons.check_rounded,
                        onTap: canSave ? _save : null,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        Text(
                          'Titel',
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: _categoryMuted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _GlassInputField(
                          controller: _titleController,
                          hint: 'z.B. Familienrunde',
                          maxLines: 1,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Text(
                              'Wörter',
                              style: GoogleFonts.nunito(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: _categoryMuted,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '$_wordCount / $_maxWords',
                              style: GoogleFonts.nunito(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _wordCount >= _minWords
                                    ? _categoryMuted
                                    : const Color(0xFFEF4444),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        _GlassInputField(
                          controller: _wordsController,
                          hint: 'Ein Wort pro Zeile',
                          maxLines: 10,
                          minLines: 8,
                        ),
                        const SizedBox(height: 8),
                        if (_wordCount < _minWords)
                          Text(
                            'Mindestens $_minWords Wörter erforderlich.',
                            style: GoogleFonts.nunito(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFEF4444),
                            ),
                          ),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              _error!,
                              style: GoogleFonts.nunito(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFEF4444),
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: _SecondaryPillButton(
                          label: 'Abbrechen',
                          onTap: () => Navigator.pop(context),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _PrimaryPillButton(
                          label: 'Speichern',
                          icon: Icons.check_rounded,
                          onTap: canSave ? _save : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomListCard extends StatelessWidget {
  final CustomWordList list;
  final EffectsConfig effects;
  final VoidCallback onPlay;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CustomListCard({
    required this.list,
    required this.effects,
    required this.onPlay,
    required this.onEdit,
    required this.onDelete,
  });

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day.$month.$year';
  }

  @override
  Widget build(BuildContext context) {
    final blurSigma = effects.blur(high: 16, medium: 10, low: 0);
    final shadowBlur = effects.shadowBlur(high: 20, medium: 14, low: 8);

    return GlassBackdrop(
      blurSigma: blurSigma,
      borderRadius: BorderRadius.circular(_categoryCardRadius),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _categoryGlass,
          borderRadius: BorderRadius.circular(_categoryCardRadius),
          border: Border.all(color: _categoryBorder, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: shadowBlur,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              list.title,
              style: GoogleFonts.fredoka(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _categoryText,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${list.wordCount} Wörter',
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _categoryMuted,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              list.lastPlayedAt == null
                  ? 'Noch nie gespielt'
                  : 'Zuletzt gespielt: ${_formatDate(list.lastPlayedAt!)}',
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _categoryMuted.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _PrimaryPillButton(
                    label: 'Spielen',
                    icon: Icons.play_arrow_rounded,
                    onTap: onPlay,
                  ),
                ),
                const SizedBox(width: 8),
                _IconPillButton(
                  icon: Icons.edit_rounded,
                  onTap: onEdit,
                ),
                const SizedBox(width: 8),
                _IconPillButton(
                  icon: Icons.delete_outline_rounded,
                  onTap: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: GlassBackdrop(
          blurSigma: 12,
          borderRadius: BorderRadius.circular(_categoryCardRadius),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _categoryGlass,
              borderRadius: BorderRadius.circular(_categoryCardRadius),
              border: Border.all(color: _categoryBorder, width: 1.2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.edit_note_rounded,
                  size: 36,
                  color: _categoryMuted,
                ),
                const SizedBox(height: 10),
                Text(
                  'Noch keine Listen erstellt',
                  style: GoogleFonts.fredoka(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _categoryText,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Lege jetzt deine erste Wortliste an.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _categoryMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderIconButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.75),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.55)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Icon(icon, color: _categoryText, size: 22),
      ),
    );
  }
}

class _PrimaryPillButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;

  const _PrimaryPillButton({
    required this.label,
    this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: isEnabled ? 1 : 0.5,
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: _categoryPrimary,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: _categoryPrimary.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: _categoryText, size: 20),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: GoogleFonts.fredoka(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _categoryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecondaryPillButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SecondaryPillButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _categoryText,
            ),
          ),
        ),
      ),
    );
  }
}

class _IconPillButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _IconPillButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.75),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
        ),
        child: Icon(icon, color: _categoryText, size: 20),
      ),
    );
  }
}

class _GlassInputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int? maxLines;
  final int? minLines;
  final ValueChanged<String>? onChanged;

  const _GlassInputField({
    required this.controller,
    required this.hint,
    this.maxLines,
    this.minLines,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GlassBackdrop(
      blurSigma: 16,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _categoryGlass,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _categoryBorder),
        ),
        child: TextField(
          controller: controller,
          maxLines: maxLines,
          minLines: minLines,
          onChanged: onChanged,
          style: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _categoryText,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _categoryMuted.withValues(alpha: 0.6),
            ),
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }
}

class _CategoryBackground extends StatelessWidget {
  const _CategoryBackground();

  @override
  Widget build(BuildContext context) {
    final effects = EffectsConfig.of(context);
    final blurRadius = effects.shadowBlur(high: 140, medium: 110, low: 70);
    final spreadRadius = effects.shadowBlur(high: 18, medium: 12, low: 8);
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _categoryBackgroundTop,
            _categoryBackgroundMid,
            _categoryBackgroundBottom,
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -100,
            right: -60,
            child: _GlowOrb(
              color: const Color(0xFFFFF1A6).withValues(alpha: 0.35),
              size: 280,
              blurRadius: blurRadius,
              spreadRadius: spreadRadius,
            ),
          ),
          Positioned(
            bottom: -140,
            left: -80,
            child: _GlowOrb(
              color: const Color(0xFFFF9FCE).withValues(alpha: 0.28),
              size: 320,
              blurRadius: blurRadius,
              spreadRadius: spreadRadius,
            ),
          ),
          Positioned(
            top: 180,
            right: -80,
            child: _GlowOrb(
              color: const Color(0xFF7DD3FC).withValues(alpha: 0.22),
              size: 240,
              blurRadius: blurRadius,
              spreadRadius: spreadRadius,
            ),
          ),
          Positioned(
            top: 90,
            left: 40,
            child: _DecorDot(
              size: 12,
              color: const Color(0xFF60A5FA).withValues(alpha: 0.7),
            ),
          ),
          Positioned(
            top: 140,
            right: 80,
            child: _DecorDiamond(
              size: 14,
              color: const Color(0xFFF472B6).withValues(alpha: 0.65),
            ),
          ),
          Positioned(
            bottom: 180,
            left: 50,
            child: _DecorDot(
              size: 14,
              color: const Color(0xFF34D399).withValues(alpha: 0.6),
            ),
          ),
          Positioned(
            bottom: 120,
            right: 60,
            child: _DecorDiamond(
              size: 12,
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;
  final double blurRadius;
  final double spreadRadius;

  const _GlowOrb({
    required this.size,
    required this.color,
    required this.blurRadius,
    required this.spreadRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.6),
            blurRadius: blurRadius,
            spreadRadius: spreadRadius,
          ),
        ],
      ),
    );
  }
}

class _DecorDot extends StatelessWidget {
  final double size;
  final Color color;

  const _DecorDot({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}

class _DecorDiamond extends StatelessWidget {
  final double size;
  final Color color;

  const _DecorDiamond({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: math.pi / 4,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}

class _NoScrollbarBehavior extends ScrollBehavior {
  const _NoScrollbarBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}
