import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../services/ai_wordlist_service.dart';
import '../services/supabase_auth_service.dart';
import '../services/sound_service.dart';
import '../services/custom_word_storage.dart';
import '../services/game_settings_storage.dart';
import '../services/supabase_wordlist_repository.dart';
import '../engine/stirnraten_engine.dart';
import '../engine/drinking_balance.dart';
import '../utils/sensor_helper.dart';
import '../utils/tilt_controller.dart';
import '../utils/effects_quality.dart';
import '../data/words.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/hud_timer.dart';
import '../widgets/category_card.dart';
import '../widgets/results_list.dart';
import '../widgets/settings_panel.dart';
import '../theme/stirnraten_colors.dart';
import '../monetization/monetization_controller.dart';
import '../monetization/premium_paywall.dart';
import '../utils/wordlist_terms.dart';
import '../utils/word_token_count.dart';
import 'ai_wordlist_generator_screen.dart';

const double _tiltNeutralZoneDeg = 10;
const double _tiltTriggerDeg = 20;
const int _tiltHoldMs = 150;
const int _tiltCooldownMs = 400;
const int _tiltCalibrationMs = 1000;

class StirnratenScreen extends StatefulWidget {
  const StirnratenScreen({super.key});

  @override
  State<StirnratenScreen> createState() => _StirnratenScreenState();
}

class _StirnratenScreenState extends State<StirnratenScreen>
    with WidgetsBindingObserver {
  final CustomWordStorage _customWordStorage = CustomWordStorage();
  final GameSettingsStorage _settingsStorage = GameSettingsStorage();
  final StirnratenEngine _engine = StirnratenEngine();
  final Set<StirnratenCategory> _selectedCategories = <StirnratenCategory>{};
  bool _showSettingsPanel = false;
  int _sidebarIndex = 0;
  bool _resultsExpanded = false;
  Timer? _gameTimer;
  Timer? _countdownTimer;
  Timer? _countdownStartStopTimer;
  late final ValueNotifier<String> _timerText;
  late final ValueNotifier<String> _wordText;
  late final ValueNotifier<bool> _timerBlinkOn;
  bool _endCountdownStarted = false;
  bool _isPaused = false;

  // Sensor handling
  final _tiltController = TiltController(
    neutralZoneDeg: _tiltNeutralZoneDeg,
    triggerDeg: _tiltTriggerDeg,
    holdMs: _tiltHoldMs,
    cooldownMs: _tiltCooldownMs,
    calibrationMs: _tiltCalibrationMs,
  );
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  bool _canSkip = true;
  bool _sensorPermissionGranted = true;
  bool _showFallbackButtons = false;
  bool _receivedSensorEvent = false;
  Timer? _sensorAvailabilityTimer;

  // Feedback
  Color? _feedbackColor;
  String? _feedbackMessage;
  Timer? _feedbackTimer;
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  String _searchQuery = '';
  List<CategoryCardData> _categoryItems = [];
  List<CustomWordList> _customWordLists = [];

  GameSnapshot get _snapshot => _engine.snapshot;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode()
      ..addListener(() {
        if (mounted) {
          setState(() {});
        }
      });
    _timerText = ValueNotifier(_formatTime(_snapshot.timeLeft));
    _wordText = ValueNotifier('');
    _timerBlinkOn = ValueNotifier(false);
    _categoryItems = _buildCategoryItems();
    _loadCustomWordLists();
    _loadGameSettings();
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _countdownTimer?.cancel();
    _countdownStartStopTimer?.cancel();
    _feedbackTimer?.cancel();
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;
    _sensorAvailabilityTimer?.cancel();
    _tiltController.stop();
    WidgetsBinding.instance.removeObserver(this);
    _timerText.dispose();
    _wordText.dispose();

    if (kDebugMode) {
      debugPrint('🎮 Stirnraten: Sensors cleaned up');
    }

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _timerBlinkOn.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_snapshot.state != StirnratenGameState.playing) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _accelerometerSubscription?.pause();
    } else if (state == AppLifecycleState.resumed) {
      _accelerometerSubscription?.resume();
    }
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
              await _startCountdownWithWords(list.words);
            }
          },
        ),
      ),
    );
    await _loadCustomWordLists();
  }

  Future<void> _loadGameSettings() async {
    final savedTime = await _settingsStorage.getSelectedTime();
    final savedMode = await _settingsStorage.getSelectedMode();
    if (!mounted) return;
    if (savedTime == null && savedMode == null) return;
    setState(() {
      if (savedTime != null) {
        _engine.setSelectedTime(savedTime);
      }
      if (savedMode != null) {
        _engine.setSelectedMode(savedMode);
      }
    });
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

  Future<void> _startCountdownWithWords(List<String> words) async {
    // Unlock audio context on user interaction
    context.read<SoundService>().unlock();

    if (!kIsWeb) {
      _sensorPermissionGranted = await requestSensorPermission();
    }

    if (!mounted) return;

    // Force landscape for the game
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    setState(() {
      _showSettingsPanel = false;
      _engine.startCountdown(words);
    });
    _syncCountdownUI();
    _startCountdownIntroSound();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final shouldStart = _engine.tickCountdown();
      if (!shouldStart) {
        _syncCountdownUI();
      } else {
        timer.cancel();
        _startGame();
      }
    });
  }

  void _startCountdownIntroSound() {
    _countdownStartStopTimer?.cancel();
    final sound = context.read<SoundService>();
    sound.playCountdownStart();
    _countdownStartStopTimer = Timer(const Duration(seconds: 3), () {
      sound.stopCountdownStart();
    });
  }

  void _syncCountdownUI() {
    _wordText.value = '${_snapshot.countdown}';
    _timerText.value = _formatCountdown(_snapshot.countdown);
    if (_timerBlinkOn.value) {
      _timerBlinkOn.value = false;
    }
  }

  void _syncGameUI() {
    _wordText.value = _snapshot.currentWord.toUpperCase();
    _timerText.value = _formatTime(_snapshot.timeLeft);
    if (_snapshot.timeLeft > 5 && _timerBlinkOn.value) {
      _timerBlinkOn.value = false;
    }
  }

  void _startGame() {
    if (kDebugMode) {
      debugPrint('🎮 Stirnraten: Spiel wird gestartet...');
    }

    setState(() {
      _engine.startGame();
      _feedbackColor = null; // Reset any lingering feedback
      _showFallbackButtons = !_sensorPermissionGranted;
    });
    _countdownStartStopTimer?.cancel();
    context.read<SoundService>().stopCountdownStart();
    _endCountdownStarted = false;
    _syncGameUI();
    if (_snapshot.state == StirnratenGameState.result) {
      _endGame();
      return;
    }
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (!kIsWeb && _sensorPermissionGranted) {
      _tiltController.start(nowMs);
    }
    _receivedSensorEvent = false;
    _sensorAvailabilityTimer?.cancel();
    if (!kIsWeb && _sensorPermissionGranted) {
      _sensorAvailabilityTimer = Timer(
        const Duration(milliseconds: 1200),
        _checkSensorAvailability,
      );
    }

    context.read<SoundService>().playStart();
    _startTimer();
    if (!kIsWeb && _sensorPermissionGranted) {
      _startSensors();
    }

    if (kDebugMode) {
      debugPrint('✅ Stirnraten: Spiel erfolgreich gestartet');
    }
  }

  void _startTimer() {
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final shouldEnd = _engine.tickTimer();
      if (shouldEnd) {
        _endGame();
      } else {
        _timerText.value = _formatTime(_snapshot.timeLeft);
        final timeLeft = _snapshot.timeLeft;
        if (timeLeft == 5 && !_endCountdownStarted) {
          _endCountdownStarted = true;
          context.read<SoundService>().playCountdown();
        } else if (timeLeft > 5) {
          _endCountdownStarted = false;
        }
        if (timeLeft <= 5 && timeLeft > 0) {
          _timerBlinkOn.value = !_timerBlinkOn.value;
        } else if (_timerBlinkOn.value) {
          _timerBlinkOn.value = false;
        }
      }
    });
  }

  void _startSensors() {
    // Cancel existing subscription if any
    _accelerometerSubscription?.cancel();

    if (kDebugMode) {
      debugPrint('🎮 Stirnraten: Sensor-Listener werden gestartet...');
      if (!kIsWeb) {
        try {
          debugPrint('📱 Plattform: ${defaultTargetPlatform.name}');
        } catch (e) {
          debugPrint('⚠️ Plattformerkennung fehlgeschlagen: $e');
        }
      }
    }

    // Mobile: Use Dart sensor stream
    if (kDebugMode) {
      debugPrint('📱 Dart-Sensorstream für Mobilgerät aktiv');
    }
    _accelerometerSubscription = accelerometerEventStream(
      samplingPeriod: SensorInterval.gameInterval,
    ).listen(
      (AccelerometerEvent event) {
        _processSensorData(event.x, event.y, event.z);
      },
      onError: (error) {
        if (kDebugMode) {
          print('⚠️ Sensorfehler: $error');
        }
      },
      cancelOnError: false,
    );

    if (kDebugMode) {
      debugPrint('✅ Sensor-Listener aktiv');
    }
  }

  void _processSensorData(double x, double y, double z) {
    if (_snapshot.state != StirnratenGameState.playing) return;
    _receivedSensorEvent = true;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final action = _tiltController.update(
      x: x,
      y: y,
      z: z,
      nowMs: nowMs,
      allowTrigger: _canSkip,
    );
    if (kDebugMode && nowMs % 500 < 35) {
      debugPrint(
        'NeigungsΔ: ${_tiltController.lastDeltaDeg.toStringAsFixed(1)}° '
        'Basis: ${_tiltController.baselineAngleDeg.toStringAsFixed(1)}° '
        'Phase: ${_tiltController.phase}',
      );
    }

    if (action == TiltGestureAction.correct) {
      _handleCorrect();
    } else if (action == TiltGestureAction.pass) {
      _handlePass();
    }
  }

  void _checkSensorAvailability() {
    if (kIsWeb) return;
    if (!mounted || _snapshot.state != StirnratenGameState.playing) return;
    if (_receivedSensorEvent) {
      if (_showFallbackButtons) {
        setState(() => _showFallbackButtons = false);
      }
      return;
    }
    if (!_showFallbackButtons) {
      setState(() => _showFallbackButtons = true);
    }
  }

  void _nextWord() {
    final advanced = _engine.advanceWord();
    if (!advanced) {
      _endGame();
      return;
    }
    _wordText.value = _snapshot.currentWord.toUpperCase();
  }

  void _handleCorrect() {
    _handleGameAction(GameAction.correct);
  }

  void _handlePass() {
    _handleGameAction(GameAction.skip);
  }

  void _handleGameAction(GameAction action) {
    if (_snapshot.state != StirnratenGameState.playing || !_canSkip) return;
    if (_tiltController.isCalibrating && !_showFallbackButtons) return;
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
      debugPrint('Richtig-Aktion ausgelöst');
    }

    _engine.applyAction(GameAction.correct);
    setState(() {});

    HapticFeedback.heavyImpact();
    context.read<SoundService>().playCorrect().then((_) {
      if (kDebugMode) {
        debugPrint('Richtig-Sound abgespielt');
      }
    }).catchError((e) {
      if (kDebugMode) {
        debugPrint('Soundfehler: $e');
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
      debugPrint('Überspringen-Aktion ausgelöst');
    }

    _engine.applyAction(GameAction.skip);
    setState(() {});

    context.read<SoundService>().playWrong().then((_) {
      if (kDebugMode) {
        debugPrint('Falsch-Sound abgespielt');
      }
    }).catchError((e) {
      if (kDebugMode) {
        debugPrint('Soundfehler: $e');
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
      debugPrint('K.-o.-Modus fehlgeschlagen');
    }

    _engine.applyAction(GameAction.skip);
    setState(() {});

    HapticFeedback.mediumImpact();
    context.read<SoundService>().playWrong();

    _showFeedback(
      const Color(0xCCEF4444),
      label: 'Spiel vorbei',
      durationMs: 650,
      onFinished: _endGame,
    );
  }

  void _applyHardcoreSkip() {
    if (kDebugMode) {
      debugPrint('Schwer-Modus Überspringen-Strafe');
    }

    final outcome = _engine.applyAction(GameAction.skip);
    setState(() {});

    HapticFeedback.mediumImpact();
    context.read<SoundService>().playWrong();

    _showFeedback(
      const Color(0xCCEF4444),
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
      debugPrint('Trinkspiel-Überspringen');
    }

    _engine.applyAction(GameAction.skip);
    setState(() {});

    HapticFeedback.lightImpact();
    context.read<SoundService>().playWrong();

    _showFeedback(
      const Color(0xCCEF4444),
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

  void _togglePause() {
    if (_snapshot.state != StirnratenGameState.playing) return;
    setState(() {
      if (_isPaused) {
        _isPaused = false;
        _startTimer();
      } else {
        _isPaused = true;
        _gameTimer?.cancel();
        _tiltController.stop();
      }
    });
  }

  void _endGame() {
    _gameTimer?.cancel();
    _accelerometerSubscription?.cancel();
    _sensorAvailabilityTimer?.cancel();
    _tiltController.stop();
    if (_timerBlinkOn.value) {
      _timerBlinkOn.value = false;
    }
    _countdownStartStopTimer?.cancel();
    context.read<SoundService>().stopCountdownStart();
    context.read<SoundService>().stopCountdown();

    context.read<SoundService>().playEnd();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    setState(() {
      _engine.endGame();
    });
  }

  Future<void> _showExitGameConfirmDialog() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => const _ExitGameConfirmDialog(),
    );
    if (shouldExit != true || !mounted) return;
    _exitGameToMainMenu();
  }

  void _exitGameToMainMenu() {
    // Keep cleanup explicit so game resources are released before navigating back.
    _gameTimer?.cancel();
    _countdownTimer?.cancel();
    _countdownStartStopTimer?.cancel();
    _feedbackTimer?.cancel();
    _sensorAvailabilityTimer?.cancel();
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;
    _tiltController.stop();

    if (_timerBlinkOn.value) {
      _timerBlinkOn.value = false;
    }

    context.read<SoundService>().stopCountdownStart();
    context.read<SoundService>().stopCountdown();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    setState(() {
      _feedbackColor = null;
      _feedbackMessage = null;
      _showFallbackButtons = false;
      _endCountdownStarted = false;
      _isPaused = false;
      _selectedCategories.clear();
      _engine.resetToSetup();
    });

    Navigator.pop(context);
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
        return _buildGame();
      case StirnratenGameState.playing:
        return _buildGame();
      case StirnratenGameState.result:
        return _buildResult();
    }
  }

  List<CategoryCardData> _buildCategoryItems() {
    // Own + AI lists must stay pinned to the first position.
    final ordered = List<StirnratenCategory>.from(StirnratenCategory.values);
    ordered.remove(StirnratenCategory.ownWords);
    ordered.insert(0, StirnratenCategory.ownWords);
    return ordered.map((category) {
      final title = category == StirnratenCategory.ownWords
          ? 'Eigene & KI-Listen'
          : (StirnratenData.categoryNames[category] ?? category.name);
      final wordCount = StirnratenData.getWords(category).length;
      final subtitle = category == StirnratenCategory.ownWords
          ? (_customWordLists.isEmpty
              ? 'Eigene Listen erstellen'
              : '${_customWordLists.length} Listen')
          : '';
      final tags = wordCount >= 120 ? const ['BELIEBT'] : const <String>[];
      final difficulty = wordCount >= 140 ? 'SCHWER' : null;
      final progress = wordCount >= 140 ? 0.75 : null;
      return CategoryCardData(
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

  List<CategoryCardData> get _filteredCategories {
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
    final isLargeScreen = MediaQuery.sizeOf(context).width > 800;
    if (isLargeScreen) {
      return _buildLargeSetup();
    }
    return _buildSmallSetup();
  }

  Widget _buildLargeSetup() {
    return Row(
      children: [
        Container(
          width: 260,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'STIRNRATEN',
                      style: GoogleFonts.fredoka(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      children: [
                        _SidebarItem(
                          icon: Icons.grid_view_rounded,
                          label: 'Kategorien',
                          isSelected: _sidebarIndex == 0,
                          onTap: () => setState(() => _sidebarIndex = 0),
                        ),
                        const SizedBox(height: 8),
                        _SidebarItem(
                          icon: Icons.edit_note_rounded,
                          label: 'Eigene Wörter',
                          isSelected: _sidebarIndex == 1,
                          onTap: () => setState(() => _sidebarIndex = 1),
                        ),
                        const SizedBox(height: 8),
                        _SidebarItem(
                          icon: Icons.settings_rounded,
                          label: 'Einstellungen',
                          isSelected: _sidebarIndex == 2,
                          onTap: () => setState(() => _sidebarIndex = 2),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: _SidebarItem(
                    icon: Icons.arrow_back_rounded,
                    label: 'Hauptmenü',
                    isSelected: false,
                    onTap: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _buildDetailContent(),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailContent() {
    if (_sidebarIndex == 1) {
      return CustomWordsScreen(
        key: const ValueKey('CustomWords'),
        storage: _customWordStorage,
        showBackButton: false,
        onPlay: (list) {
          final words = list.words;
          if (words.isNotEmpty) {
            _selectedCategories.clear();
            _selectedCategories.add(StirnratenCategory.ownWords);
            _startCountdownWithWords(words);
          }
        },
      );
    } else if (_sidebarIndex == 2) {
      return Scaffold(
        key: const ValueKey('Settings'),
        body: Stack(
          children: [
            const _CategoryBackground(),
            Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Einstellungen',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 32),
                      SettingsPanel(
                        selectedTime: _snapshot.selectedTime,
                        selectedMode: _snapshot.selectedMode,
                        onTimeChanged: (value) {
                          setState(() => _engine.setSelectedTime(value));
                          _settingsStorage.saveSelectedTime(value);
                        },
                        onModeChanged: (mode) {
                          setState(() => _engine.setSelectedMode(mode));
                          _settingsStorage.saveSelectedMode(mode);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return _buildSmallSetup(key: const ValueKey('Categories'), hideControls: true);
  }

  Widget _buildSmallSetup({Key? key, bool hideControls = false}) {
    final filteredCategories = _filteredCategories;
    final selectedCount = _selectedCategories.length;
    const bottomBarHeight = 112.0;
    final topInset = MediaQuery.of(context).padding.top;

    return DefaultTextStyle(
      key: key,
      style: GoogleFonts.nunito(
        color: StirnratenColors.categoryText,
        fontWeight: FontWeight.w600,
      ),
      child: Stack(
        children: [
          const _CategoryBackground(),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: SafeArea(
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
                      onBack: hideControls ? null : () => Navigator.pop(context),
                      onSettings: hideControls ? null : _toggleSettingsPanel,
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
                      crossAxisCount: MediaQuery.sizeOf(context).width > 800 ? 4 : (MediaQuery.sizeOf(context).width > 600 ? 3 : 2),
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childCount: filteredCategories.length,
                      itemBuilder: (context, index) {
                        final item = filteredCategories[index];
                        final isSelected =
                            _selectedCategories.contains(item.category);
                        return CategoryCard(
                          data: item,
                          isSelected: isSelected,
                          onTap: () {
                            if (item.isOwnWords) {
                              if (hideControls) {
                                setState(() => _sidebarIndex = 1);
                              } else {
                                _openCustomWordsScreen();
                              }
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
          ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: _BottomActionBar(
                selectedCount: selectedCount,
                onPressed: selectedCount == 0 ? null : _startSelectedCategories,
              ),
            ),
          ),
          if (!hideControls && _showSettingsPanel)
            Positioned.fill(
              child: GestureDetector(
                onTap: _closeSettingsPanel,
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  color: Colors.black.withValues(alpha: 0.14),
                ),
              ),
            ),
          if (!hideControls && _showSettingsPanel)
            Positioned(
              top: topInset + 88,
              right: 20,
              child: SettingsPanel(
                selectedTime: _snapshot.selectedTime,
                selectedMode: _snapshot.selectedMode,
                onTimeChanged: (value) {
                  setState(() => _engine.setSelectedTime(value));
                  _settingsStorage.saveSelectedTime(value);
                },
                onModeChanged: (mode) {
                  setState(() => _engine.setSelectedMode(mode));
                  _settingsStorage.saveSelectedMode(mode);
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

  void _toggleResultsExpanded() {
    setState(() => _resultsExpanded = !_resultsExpanded);
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
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          _handlePass();
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          _handleCorrect();
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.escape) {
          _showExitGameConfirmDialog();
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.space) {
          if (_snapshot.state == StirnratenGameState.playing) {
            _togglePause();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Stack(
      children: [
        Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFFFFD600),
                Color(0xFFFF2D55),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        const Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    Color(0x33FFFFFF),
                    Color(0x00FFFFFF),
                  ],
                  radius: 0.75,
                  center: Alignment(0.0, -0.2),
                ),
              ),
            ),
          ),
        ),
        // Touch controls - Links Überspringen, Rechts richtig (always available as fallback)
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
        SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                child: HudTimerRow(
                  timerText: _timerText,
                  timerBlink: _timerBlinkOn,
                  score: _snapshot.score,
                  onExitTap: _showExitGameConfirmDialog,
                ),
              ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: SizedBox(
                      width: double.infinity,
                      child: ValueListenableBuilder<String>(
                        valueListenable: _wordText,
                        builder: (context, value, _) {
                          return FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              value,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.fredoka(
                                fontSize: 96,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 22,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
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
        if (_isPaused)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.6),
              child: Center(
                child: Text(
                  'PAUSE',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 48,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 2.0,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
    );
  }

  String _formatTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatCountdown(int totalSeconds) {
    return '00:${totalSeconds.toString().padLeft(2, '0')}';
  }

  Widget _buildDrinkingBalancePanel({
    required DrinkingBalance balance,
  }) {
    final netLabel = balance.finalGive > 0
        ? '➡️ Du verteilst ${balance.finalGive} Schlucke'
        : balance.finalTake > 0
            ? '➡️ Du trinkst ${balance.finalTake} Schlucke'
            : '➡️ Keine Schlucke';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🍺 Trinkbilanz',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            netLabel,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsSection(List<GameResult> results) {
    final listHeight = (MediaQuery.of(context).size.height * 0.35)
        .clamp(220.0, 360.0)
        .toDouble();
    final icon = _resultsExpanded
        ? Icons.expand_less_rounded
        : Icons.expand_more_rounded;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: _toggleResultsExpanded,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Text(
                  'Zusammenfassung',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                Icon(icon, color: Colors.white),
              ],
            ),
          ),
        ),
        ClipRect(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            height: _resultsExpanded ? listHeight : 0,
            child: _resultsExpanded
                ? Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: ResultsList(results: results, showHeader: false),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }

  Widget _buildResult() {
    final results = _snapshot.results;
    final correctCount = results.where((result) => result.correct).length;
    final passCount = results.length - correctCount;
    final drinkingBalance = _snapshot.activeMode == GameMode.drinking
        ? DrinkingBalance.fromCounts(
            correctCount: correctCount,
            passCount: passCount,
          )
        : null;
    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  StirnratenColors.resultGradientTop,
                  StirnratenColors.resultGradientBottom,
                ],
              ),
            ),
          ),
        ),
        const Positioned.fill(
          child: IgnorePointer(
            child: _ResultConfetti(),
          ),
        ),
        SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 80,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'RUNDE BEENDET!',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 38,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.8,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.25),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          Transform.rotate(
                            angle: -math.pi / 180,
                            child: Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.18),
                                    blurRadius: 24,
                                    offset: const Offset(0, 14),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'DEIN ERGEBNIS',
                                    style: GoogleFonts.spaceGrotesk(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: StirnratenColors.resultPink,
                                      letterSpacing: 2.4,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  RichText(
                                    text: TextSpan(
                                      style: GoogleFonts.spaceGrotesk(
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF1F2937),
                                      ),
                                      children: [
                                        TextSpan(
                                          text: '${_snapshot.score} ',
                                          style: const TextStyle(fontSize: 60),
                                        ),
                                        TextSpan(
                                          text: _snapshot.score == 1
                                              ? 'Punkt'
                                              : 'Punkte',
                                          style: const TextStyle(fontSize: 26),
                                        ),
                                      ],
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (drinkingBalance != null) ...[
                            const SizedBox(height: 16),
                            _buildDrinkingBalancePanel(
                              balance: drinkingBalance,
                            ),
                          ],
                          const SizedBox(height: 24),
                          _buildResultsSection(results),
                          const SizedBox(height: 24),
                          _ResultActionButton(
                            label: 'Erneut spielen',
                            backgroundColor: StirnratenColors.resultPrimary,
                            textColor: const Color(0xFF1F2937),
                            onTap: () {
                              setState(() {
                                _engine.resetToSetup();
                              });
                            },
                            glowColor:
                                StirnratenColors.resultPrimary.withValues(
                              alpha: 0.5,
                            ),
                            isPrimary: true,
                          ),
                          const SizedBox(height: 12),
                          _ResultActionButton(
                            label: 'Zurück zum Hauptmenü',
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.2),
                            textColor: Colors.white,
                            borderColor: Colors.white.withValues(alpha: 0.3),
                            onTap: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const Positioned.fill(
          child: IgnorePointer(
            child: SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: EdgeInsets.only(bottom: 6),
                  child: SizedBox(
                    width: 120,
                    height: 4,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color(0x4DFFFFFF),
                        borderRadius: BorderRadius.all(Radius.circular(999)),
                      ),
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
}

class _ResultConfetti extends StatelessWidget {
  const _ResultConfetti();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: 90,
          left: 60,
          child: _ConfettiShape(
            color: Colors.white.withValues(alpha: 0.4),
            size: const Size(12, 12),
            rotation: 0.2,
            radius: 2,
          ),
        ),
        Positioned(
          top: 140,
          right: 80,
          child: _ConfettiShape(
            color: const Color(0xFFF9A8D4).withValues(alpha: 0.7),
            size: const Size(16, 16),
            rotation: 0.8,
            radius: 999,
          ),
        ),
        Positioned(
          bottom: 140,
          left: 90,
          child: _ConfettiShape(
            color: const Color(0xFFFDE68A).withValues(alpha: 0.8),
            size: const Size(24, 8),
            rotation: -0.2,
            radius: 2,
          ),
        ),
        Positioned(
          top: 260,
          right: 40,
          child: _ConfettiShape(
            color: Colors.white.withValues(alpha: 0.5),
            size: const Size(12, 12),
            rotation: 0.5,
            radius: 2,
          ),
        ),
        Positioned(
          bottom: 260,
          right: 140,
          child: _ConfettiShape(
            color: const Color(0xFFF472B6).withValues(alpha: 0.7),
            size: const Size(12, 12),
            rotation: 1.0,
            radius: 999,
          ),
        ),
        Positioned(
          top: 420,
          left: 40,
          child: _ConfettiShape(
            color: Colors.white.withValues(alpha: 0.35),
            size: const Size(12, 12),
            rotation: 1.2,
            radius: 2,
          ),
        ),
        Positioned(
          bottom: 100,
          right: 30,
          child: _ConfettiShape(
            color: Colors.white.withValues(alpha: 0.3),
            size: const Size(20, 20),
            rotation: -0.8,
            radius: 999,
          ),
        ),
        Positioned(
          top: 50,
          right: 120,
          child: Icon(
            Icons.celebration,
            color: Colors.white.withValues(alpha: 0.4),
            size: 40,
          ),
        ),
        Positioned(
          bottom: 280,
          left: 20,
          child: Icon(
            Icons.auto_awesome,
            color: Colors.white.withValues(alpha: 0.3),
            size: 46,
          ),
        ),
        Positioned(
          top: 200,
          left: 30,
          child: Icon(
            Icons.star,
            color: Colors.white.withValues(alpha: 0.2),
            size: 56,
          ),
        ),
        Positioned(
          top: 120,
          left: 160,
          child: Icon(
            Icons.flare,
            color: Colors.white.withValues(alpha: 0.3),
            size: 32,
          ),
        ),
      ],
    );
  }
}

class _ConfettiShape extends StatelessWidget {
  final Color color;
  final Size size;
  final double rotation;
  final double radius;

  const _ConfettiShape({
    required this.color,
    required this.size,
    required this.rotation,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotation,
      child: Container(
        width: size.width,
        height: size.height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

class _ResultActionButton extends StatefulWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final Color? borderColor;
  final Color? glowColor;
  final VoidCallback onTap;
  final bool isPrimary;

  const _ResultActionButton({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    required this.onTap,
    this.borderColor,
    this.glowColor,
    this.isPrimary = false,
  });

  @override
  State<_ResultActionButton> createState() => _ResultActionButtonState();
}

class _ResultActionButtonState extends State<_ResultActionButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) {
      setState(() => _pressed = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scale = _pressed ? 0.95 : 1.0;
    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: widget.backgroundColor,
            borderRadius: BorderRadius.circular(999),
            border: widget.borderColor == null
                ? null
                : Border.all(color: widget.borderColor!, width: 1),
            boxShadow: widget.glowColor == null
                ? null
                : [
                    BoxShadow(
                      color: widget.glowColor!,
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
          ),
          child: Center(
            child: Text(
              widget.label.toUpperCase(),
              style: GoogleFonts.spaceGrotesk(
                fontSize: widget.isPrimary ? 20 : 14,
                fontWeight: FontWeight.w700,
                color: widget.textColor,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
      ),
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
                StirnratenColors.categoryBackgroundBottom
                    .withValues(alpha: 0.0),
                StirnratenColors.categoryBackgroundBottom
                    .withValues(alpha: 0.6),
                StirnratenColors.categoryBackgroundBottom,
              ],
            ),
          ),
          child: SizedBox(
            width: double.infinity,
            child: _PrimaryActionButton(
              label: 'Spielen ($selectedCount ausgewählt)',
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
    final backgroundColor = isEnabled
        ? StirnratenColors.categoryPrimary
        : StirnratenColors.categorySurface;
    final foregroundColor = isEnabled
        ? StirnratenColors.categoryText
        : StirnratenColors.categoryMuted.withValues(alpha: 0.7);

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
                      color: StirnratenColors.categoryPrimary
                          .withValues(alpha: shadowAlpha),
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
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: StirnratenColors.categoryText,
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

class _CategoryHeaderDelegate extends SliverPersistentHeaderDelegate {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isFocused;
  final VoidCallback? onBack;
  final VoidCallback? onSettings;
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
  double get minExtent => 132;

  @override
  double get maxExtent => 132;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final showShadow = overlapsContent || shrinkOffset > 0;
    final effects = EffectsConfig.of(context);
    final shadowBlur = effects.shadowBlur(high: 12, medium: 10, low: 8);
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
              if (onBack != null)
                _IconCircleButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: onBack!,
                )
              else
                const SizedBox(width: 48),
              Expanded(
                child: Center(
                  child: Text(
                    'Stirnraten',
                    style: GoogleFonts.fredoka(
                      color: StirnratenColors.categoryText,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
              if (onSettings != null)
                _IconCircleButton(
                  icon: Icons.settings_rounded,
                  onTap: onSettings!,
                  isPrimary: true,
                )
              else
                const SizedBox(width: 48),
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

    return ClipRect(child: header);
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
          color: isFocused
              ? StirnratenColors.categoryPrimary
              : Colors.white.withValues(alpha: 0.5),
        ),
        boxShadow: isFocused
            ? [
                BoxShadow(
                  color:
                      StirnratenColors.categoryPrimary.withValues(alpha: 0.2),
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
            color: StirnratenColors.categoryMuted.withValues(alpha: 0.6),
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              maxLines: 1,
              textAlignVertical: TextAlignVertical.center,
              style: GoogleFonts.nunito(
                color: StirnratenColors.categoryText,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: 'Kategorien durchsuchen...',
                hintStyle: GoogleFonts.nunito(
                  color: StirnratenColors.categoryMuted.withValues(alpha: 0.55),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
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
        ? StirnratenColors.categoryPrimary
        : Colors.white.withValues(alpha: 0.75);
    final borderColor = widget.isPrimary
        ? StirnratenColors.categoryPrimary
        : Colors.white.withValues(alpha: 0.55);
    final iconColor = widget.isPrimary
        ? StirnratenColors.categoryText
        : StirnratenColors.categoryText.withValues(alpha: 0.8);
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
                  color:
                      StirnratenColors.categoryPrimary.withValues(alpha: 0.35),
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
  final WordlistRepository? repository;
  final AIWordlistService? aiService;
  final bool showBackButton;

  const CustomWordsScreen({
    super.key,
    required this.storage,
    required this.onPlay,
    this.repository,
    this.aiService,
    this.showBackButton = true,
  });

  @override
  State<CustomWordsScreen> createState() => _CustomWordsScreenState();
}

class _CustomWordsScreenState extends State<CustomWordsScreen> {
  List<CustomWordList> _lists = [];
  bool _loading = true;
  bool _authBusy = false;
  bool _isCloudAuthenticated = false;
  String? _cloudError;
  late final WordlistRepository? _repository;
  late final AIWordlistService? _aiService;
  SupabaseAuthService? _authService;
  StreamSubscription<dynamic>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ?? SupabaseWordlistRepository.fromEnvironment();
    // Always prefer calling the Supabase Edge Function via functions.invoke.
    // The raw HTTP endpoint variant is more error-prone (stale/invalid JWT).
    _aiService =
        widget.aiService ?? SupabaseAIWordlistService.fromInitializedClient();
    _authService = SupabaseAuthService.fromInitializedClient();
    _isCloudAuthenticated = _authService?.hasSession ?? false;
    if (_authService != null) {
      _authSubscription = _authService!.onAuthStateChange.listen((_) {
        final nowSignedIn = _authService!.hasSession;
        if (!mounted) return;
        if (_isCloudAuthenticated != nowSignedIn) {
          setState(() => _isCloudAuthenticated = nowSignedIn);
          _loadLists();
        }
      });
      unawaited(_initializeCloudSession());
    }
    _loadLists();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadLists() async {
    final localLists = await widget.storage.getLists();
    final mergedById = <String, CustomWordList>{
      for (final list in localLists) list.id: list,
    };
    String? cloudError;
    if (_repository != null && _isCloudAuthenticated) {
      try {
        final remoteLists = await _repository!.fetchListsForUser();
        for (final list in remoteLists) {
          mergedById[list.id] = list;
        }
      } catch (error) {
        cloudError = error.toString();
      }
    }
    final lists = mergedById.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    if (!mounted) return;
    setState(() {
      _lists = lists;
      _cloudError = cloudError;
      _loading = false;
    });
  }

  Future<void> _openEditor({CustomWordList? list}) async {
    if (list != null && list.source == WordListSource.ai) {
      await _renameAIList(list);
      return;
    }

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

  Future<void> _openAIGenerator() async {
    if (_repository == null || _aiService == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'KI/Supabase nicht konfiguriert. '
            'Für iOS/Xcode: scripts/generate_ios_xcode_dart_defines.sh ausführen '
            'oder flutter run --dart-define-from-file=ios/Flutter/dart_defines_prod.env',
          ),
        ),
      );
      return;
    }
    final signedIn = await _ensureCloudSignIn();
    if (!signedIn) return;
    if (!mounted) return;

    final saved = await Navigator.push<CustomWordList?>(
      context,
      MaterialPageRoute(
        builder: (context) => AIWordlistGeneratorScreen(
          aiService: _aiService!,
          repository: _repository!,
        ),
      ),
    );
    if (saved != null) {
      await _loadLists();
    }
  }

  Future<void> _initializeCloudSession() async {
    await _ensureCloudSignIn(silent: true);
  }

  Future<bool> _ensureCloudSignIn({bool silent = false}) async {
    if (_isCloudAuthenticated) return true;
    if (_authService == null) {
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Supabase Auth nicht initialisiert. Prüfe SUPABASE_URL und SUPABASE_ANON_KEY.',
            ),
          ),
        );
      }
      return false;
    }
    if (_authBusy) return false;

    setState(() => _authBusy = true);
    try {
      final ok = await _authService!.ensureAnonymousSession();
      if (!mounted) return false;
      if (!ok) {
        if (!silent) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Automatische Anmeldung konnte nicht abgeschlossen werden.',
              ),
            ),
          );
        }
        return false;
      }
      _isCloudAuthenticated = true;
      await _loadLists();
      return true;
    } catch (error) {
      if (mounted && !silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cloud-Anmeldung fehlgeschlagen: $error')),
        );
      }
      if (mounted && silent) {
        setState(() {
          _cloudError = error.toString();
        });
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _authBusy = false);
      }
    }
  }

  Future<void> _renameAIList(CustomWordList list) async {
    if (_repository == null) return;
    final signedIn = await _ensureCloudSignIn();
    if (!signedIn) return;
    if (!mounted) return;
    final controller = TextEditingController(text: list.title);
    final nextTitle = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Liste umbenennen'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Neuer Titel'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
    if (nextTitle == null || nextTitle.isEmpty || nextTitle == list.title) {
      return;
    }
    await _repository!.renameList(id: list.id, title: nextTitle);
    await _loadLists();
  }

  Future<void> _confirmDelete(CustomWordList list) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => _DeleteConfirmDialog(listTitle: list.title),
    );
    if (shouldDelete == true) {
      if (list.source == WordListSource.ai && _repository != null) {
        final signedIn = await _ensureCloudSignIn();
        if (!signedIn) return;
        await _repository!.deleteList(list.id);
      } else {
        await widget.storage.deleteList(list.id);
      }
      await _loadLists();
    }
  }

  Future<void> _playList(CustomWordList list) async {
    if (list.source == WordListSource.manual) {
      await widget.storage.markPlayed(list.id);
    }
    if (!mounted) return;
    Navigator.pop(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onPlay(list);
    });
  }

  Future<void> _openWordsPreview(CustomWordList list) async {
    final shouldEdit = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => _CustomListWordsScreen(list: list),
      ),
    );
    if (shouldEdit == true && mounted) {
      await _openEditor(list: list);
    }
  }

  @override
  Widget build(BuildContext context) {
    final effects = EffectsConfig.of(context);

    return Scaffold(
      body: Stack(
        children: [
          const _CategoryBackground(),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
                  child: Row(
                    children: [
                      if (widget.showBackButton) ...[
                        _HeaderIconButton(
                          icon: Icons.arrow_back_rounded,
                          onTap: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Text(
                          'Eigene Wörter',
                          style: GoogleFonts.fredoka(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: StirnratenColors.categoryText,
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Erstelle eigene Wortlisten und spiele sie jederzeit wieder.',
                        style: GoogleFonts.nunito(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: StirnratenColors.categoryMuted,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _SecondaryPillButton(
                        label: 'Mit KI erstellen',
                        onTap: _openAIGenerator,
                      ),
                      if (_cloudError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Cloud-Hinweis: $_cloudError',
                          style: GoogleFonts.nunito(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFEF4444),
                          ),
                        ),
                      ],
                    ],
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
                                  onViewWords: () => _openWordsPreview(list),
                                  onDelete: () => _confirmDelete(list),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
          ),
          ),
        ],
      ),
    );
  }
}

class _CustomListWordsScreen extends StatelessWidget {
  final CustomWordList list;

  const _CustomListWordsScreen({
    required this.list,
  });

  @override
  Widget build(BuildContext context) {
    final shadowBlur = EffectsConfig.of(context).shadowBlur(
      high: 18,
      medium: 12,
      low: 6,
    );
    final editLabel =
        list.source == WordListSource.ai ? 'Umbenennen' : 'Bearbeiten';
    final editIcon = list.source == WordListSource.ai
        ? Icons.drive_file_rename_outline_rounded
        : Icons.edit_rounded;

    return Scaffold(
      body: Stack(
        children: [
          const _CategoryBackground(),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: SafeArea(
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
                          'Wörter',
                          style: GoogleFonts.fredoka(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: StirnratenColors.categoryText,
                          ),
                        ),
                      ),
                      _PrimaryPillButton(
                        label: editLabel,
                        icon: editIcon,
                        onTap: () => Navigator.pop(context, true),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: StirnratenColors.categoryGlass,
                      borderRadius: BorderRadius.circular(categoryCardRadius),
                      border: Border.all(
                        color: StirnratenColors.categoryBorder,
                        width: 1.2,
                      ),
                      boxShadow: shadowBlur > 0
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: shadowBlur,
                                offset: const Offset(0, 8),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          list.title,
                          style: GoogleFonts.fredoka(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: StirnratenColors.categoryText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${list.wordCount} Wörter • ${list.language.toUpperCase()}',
                          style: GoogleFonts.nunito(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: StirnratenColors.categoryMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: list.words.isEmpty
                      ? const _EmptyState()
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                          itemCount: list.words.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final word = list.words[index];
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.72),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.6),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: StirnratenColors.categoryPrimary
                                          .withValues(alpha: 0.25),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '${index + 1}',
                                      style: GoogleFonts.nunito(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: StirnratenColors.categoryText,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      word,
                                      style: GoogleFonts.nunito(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: StirnratenColors.categoryText,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
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
    final words = _parseWords(_wordsController.text);
    setState(() {
      _wordCount = WordTokenCount.count(words);
      if (_error != null && _wordCount >= _minWords) {
        _error = null;
      }
    });
  }

  List<String> _parseWords(String raw) {
    return WordlistTerms.parse(raw);
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final words = _parseWords(_wordsController.text);
    final maxAllowed = context.read<MonetizationController>().maxWordsPerList;
    final tokenCount = WordTokenCount.count(words);
    if (title.isEmpty) {
      setState(() => _error = 'Bitte einen Titel angeben.');
      return;
    }
    if (tokenCount < _minWords) {
      setState(() => _error = 'Mindestens $_minWords Wörter erforderlich.');
      return;
    }
    if (tokenCount > maxAllowed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Maximal $maxAllowed Wörter pro Liste (aktuell: $tokenCount).',
          ),
        ),
      );
      await showPremiumPaywall(
        context,
        trigger: PaywallTrigger.wordLimit,
        message: 'Maximal $maxAllowed Wörter pro Liste.',
      );
      if (!mounted) return;
      setState(() => _error = 'Maximal $maxAllowed Wörter pro Liste.');
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
    final maxAllowed = context.watch<MonetizationController>().maxWordsPerList;
    final canSave =
        _titleController.text.trim().isNotEmpty && _wordCount >= _minWords;

    return Scaffold(
      body: Stack(
        children: [
          const _CategoryBackground(),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: SafeArea(
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
                          widget.list == null
                              ? 'Neue Liste'
                              : 'Liste bearbeiten',
                          style: GoogleFonts.fredoka(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: StirnratenColors.categoryText,
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
                            color: StirnratenColors.categoryMuted,
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
                                color: StirnratenColors.categoryMuted,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '$_wordCount / $maxAllowed',
                              style: GoogleFonts.nunito(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _wordCount >= _minWords &&
                                        _wordCount <= maxAllowed
                                    ? StirnratenColors.categoryMuted
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
                        if (_wordCount > maxAllowed)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              'Maximal $maxAllowed Wörter pro Liste.',
                              style: GoogleFonts.nunito(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFEF4444),
                              ),
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
  final VoidCallback onViewWords;
  final VoidCallback onDelete;

  const _CustomListCard({
    required this.list,
    required this.effects,
    required this.onPlay,
    required this.onViewWords,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final shadowBlur = effects.shadowBlur(high: 18, medium: 12, low: 6);

    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: StirnratenColors.categoryGlass,
          borderRadius: BorderRadius.circular(categoryCardRadius),
          border:
              Border.all(color: StirnratenColors.categoryBorder, width: 1.2),
          boxShadow: shadowBlur > 0
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: shadowBlur,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    list.title,
                    style: GoogleFonts.fredoka(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: StirnratenColors.categoryText,
                    ),
                  ),
                ),
                if (list.source == WordListSource.ai)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: StirnratenColors.categoryPrimary
                          .withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: StirnratenColors.categoryPrimary
                            .withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      'KI',
                      style: GoogleFonts.nunito(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: StirnratenColors.categoryText
                            .withValues(alpha: 0.85),
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${list.wordCount} Wörter • ${list.language.toUpperCase()}',
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: StirnratenColors.categoryMuted,
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
                Expanded(
                  child: _SecondaryPillButton(
                    label: 'Wörter',
                    icon: list.source == WordListSource.ai
                        ? Icons.drive_file_rename_outline_rounded
                        : Icons.edit_rounded,
                    onTap: onViewWords,
                  ),
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
    final effects = EffectsConfig.of(context);
    final blurSigma =
        effects.allowBlur ? effects.blur(high: 6, medium: 4, low: 0) : 0.0;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: GlassBackdrop(
          blurSigma: blurSigma,
          enableBlur: effects.allowBlur,
          borderRadius: BorderRadius.circular(categoryCardRadius),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: StirnratenColors.categoryGlass,
              borderRadius: BorderRadius.circular(categoryCardRadius),
              border: Border.all(
                color: StirnratenColors.categoryBorder,
                width: 1.2,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.edit_note_rounded,
                  size: 36,
                  color: StirnratenColors.categoryMuted,
                ),
                const SizedBox(height: 10),
                Text(
                  'Noch keine Listen erstellt',
                  style: GoogleFonts.fredoka(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: StirnratenColors.categoryText,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Lege jetzt deine erste Wortliste an.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: StirnratenColors.categoryMuted,
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
        child: Icon(icon, color: StirnratenColors.categoryText, size: 22),
      ),
    );
  }
}

class _DeleteConfirmDialog extends StatelessWidget {
  final String listTitle;

  const _DeleteConfirmDialog({required this.listTitle});

  @override
  Widget build(BuildContext context) {
    final effects = EffectsConfig.of(context);
    final blurSigma =
        effects.allowBlur ? effects.blur(high: 8, medium: 5, low: 0) : 0.0;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: GlassBackdrop(
        blurSigma: blurSigma,
        enableBlur: effects.allowBlur,
        borderRadius: BorderRadius.circular(26),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: StirnratenColors.categoryGlass,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: StirnratenColors.categoryBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 26,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.25),
                      ),
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: Color(0xFFEF4444),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Liste löschen',
                      style: GoogleFonts.fredoka(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: StirnratenColors.categoryText,
                      ),
                    ),
                  ),
                  _HeaderIconButton(
                    icon: Icons.close_rounded,
                    onTap: () => Navigator.pop(context, false),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '"$listTitle" wirklich löschen?',
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: StirnratenColors.categoryMuted,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _SecondaryPillButton(
                      label: 'Abbrechen',
                      onTap: () => Navigator.pop(context, false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DangerPillButton(
                      label: 'Löschen',
                      icon: Icons.delete_rounded,
                      onTap: () => Navigator.pop(context, true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExitGameConfirmDialog extends StatelessWidget {
  const _ExitGameConfirmDialog();

  @override
  Widget build(BuildContext context) {
    final effects = EffectsConfig.of(context);
    final blurSigma =
        effects.allowBlur ? effects.blur(high: 8, medium: 5, low: 0) : 0.0;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: GlassBackdrop(
        blurSigma: blurSigma,
        enableBlur: effects.allowBlur,
        borderRadius: BorderRadius.circular(26),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: StirnratenColors.categoryGlass,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: StirnratenColors.categoryBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 26,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.25),
                      ),
                    ),
                    child: const Icon(
                      Icons.meeting_room_rounded,
                      color: Color(0xFFEF4444),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Spiel wirklich beenden?',
                      style: GoogleFonts.fredoka(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: StirnratenColors.categoryText,
                      ),
                    ),
                  ),
                  _HeaderIconButton(
                    icon: Icons.close_rounded,
                    onTap: () => Navigator.pop(context, false),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Dein aktueller Fortschritt geht verloren.',
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: StirnratenColors.categoryMuted,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _SecondaryPillButton(
                      label: 'Abbrechen',
                      onTap: () => Navigator.pop(context, false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DangerPillButton(
                      label: 'Beenden',
                      icon: Icons.meeting_room_rounded,
                      onTap: () => Navigator.pop(context, true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
            color: StirnratenColors.categoryPrimary,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: StirnratenColors.categoryPrimary.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: StirnratenColors.categoryText, size: 20),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: GoogleFonts.fredoka(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: StirnratenColors.categoryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DangerPillButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;

  const _DangerPillButton({
    required this.label,
    this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onTap != null;
    const danger = Color(0xFFEF4444);
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: isEnabled ? 1 : 0.5,
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: danger,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: danger.withValues(alpha: 0.30),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: StirnratenColors.categoryText, size: 20),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: GoogleFonts.fredoka(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: StirnratenColors.categoryText,
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
  final IconData? icon;
  final VoidCallback onTap;

  const _SecondaryPillButton({
    required this.label,
    this.icon,
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: StirnratenColors.categoryText, size: 18),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: StirnratenColors.categoryText,
                ),
              ),
            ],
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
        child: Icon(icon, color: StirnratenColors.categoryText, size: 20),
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
    final effects = EffectsConfig.of(context);
    final blurSigma =
        effects.allowBlur ? effects.blur(high: 6, medium: 4, low: 0) : 0.0;
    return GlassBackdrop(
      blurSigma: blurSigma,
      enableBlur: effects.allowBlur,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: StirnratenColors.categoryGlass,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: StirnratenColors.categoryBorder),
        ),
        child: TextField(
          controller: controller,
          maxLines: maxLines,
          minLines: minLines,
          onChanged: onChanged,
          style: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: StirnratenColors.categoryText,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: StirnratenColors.categoryMuted.withValues(alpha: 0.6),
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
    final blurRadius = effects.shadowBlur(high: 95, medium: 70, low: 45);
    final spreadRadius = effects.shadowBlur(high: 12, medium: 8, low: 5);
    return RepaintBoundary(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              StirnratenColors.categoryBackgroundTop,
              StirnratenColors.categoryBackgroundMid,
              StirnratenColors.categoryBackgroundBottom,
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

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? Colors.white : Colors.white60;
    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        selected: isSelected,
        selectedTileColor: Colors.white.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24),
        onTap: onTap,
      ),
    );
  }
}
