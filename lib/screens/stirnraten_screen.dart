import 'dart:async';
import 'dart:ui';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:provider/provider.dart';
import '../services/sound_service.dart';
import '../utils/sensor_helper.dart';
import '../data/words.dart';
import '../widgets/glass_widgets.dart';

enum StirnratenGameState { setup, countdown, playing, result }

class StirnratenScreen extends StatefulWidget {
  const StirnratenScreen({super.key});

  @override
  State<StirnratenScreen> createState() => _StirnratenScreenState();
}

class _StirnratenScreenState extends State<StirnratenScreen> {
  StirnratenGameState _gameState = StirnratenGameState.setup;
  List<String> _currentWords = [];
  List<Map<String, dynamic>> _results = []; // {word: String, correct: bool}
  int _score = 0;
  int _timeLeft = 60;
  int _countdown = 3;
  Timer? _gameTimer;
  Timer? _countdownTimer;
  String _currentWord = "";
  
  // Sensor handling
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  bool _canSkip = true;
  bool _neutralPosition = true;
  DateTime _lastSensorProcessing = DateTime.now();
  static const Duration _sensorThrottle = Duration(milliseconds: 50);
  
  // Feedback
  Color? _feedbackColor;
  Timer? _feedbackTimer;

  @override
  void dispose() {
    _gameTimer?.cancel();
    _countdownTimer?.cancel();
    _feedbackTimer?.cancel();
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;
    
    if (kDebugMode) {
      debugPrint('🎮 Stirnraten: Sensors cleaned up');
    }
    
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  void _startCountdown(StirnratenCategory category) async {
    // Unlock audio context on user interaction
    context.read<SoundService>().unlock();

    // Request sensor permission (Web/iOS)
    await requestSensorPermission();

    // Force landscape for the game
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    setState(() {
      _currentWords = List.from(StirnratenData.getWords(category))..shuffle();
      _score = 0;
      _timeLeft = 60;
      _results = [];
      _countdown = 3;
      _gameState = StirnratenGameState.countdown;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 1) {
        setState(() => _countdown--);
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
      _gameState = StirnratenGameState.playing;
      _canSkip = true;
      _neutralPosition = true;
      _feedbackColor = null; // Reset any lingering feedback
    });

    context.read<SoundService>().playStart();
    _nextWord();
    _startTimer();
    _startSensors();
    
    if (kDebugMode) {
      debugPrint('✅ Stirnraten: Game started successfully');
    }
  }

  void _startTimer() {
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 0) {
        setState(() => _timeLeft--);
      } else {
        _endGame();
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
          final platform = Platform.operatingSystem;
          debugPrint('📱 Platform: $platform');
        } catch (e) {
          debugPrint('⚠️ Platform detection failed: $e');
        }
      }
    }
    
    // Mobile-optimized sensor stream configuration
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

    // Web fallback (sekundär)
    if (kIsWeb) {
      Timer.periodic(const Duration(milliseconds: 100), (timer) {
        if (_gameState != StirnratenGameState.playing) {
          timer.cancel();
          return;
        }
        
        final webData = getWebAccelerometerData();
        if (webData[0] != 0 || webData[1] != 0 || webData[2] != 0) {
           _processSensorData(webData[0], webData[1], webData[2]);
        }
      });
    }
    
    if (kDebugMode) {
      debugPrint('✅ Sensor listeners activated');
    }
  }

  void _processSensorData(double x, double y, double z) {
    if (_gameState != StirnratenGameState.playing || !_canSkip) return;

    // Throttle: Process sensor data max every 50ms
    final now = DateTime.now();
    if (now.difference(_lastSensorProcessing) < _sensorThrottle) return;
    _lastSensorProcessing = now;

    // Adaptive Thresholds: Mobile-Geräte haben oft andere Sensitivität
    // Y-Achse für Landscape-Modus: Kippen nach vorne (positiv) oder hinten (negativ)
    const bool isMobile = !kIsWeb;
    
    // Mobile: Etwas höhere Thresholds für stabilere Erkennung
    // Web: Niedrigere Thresholds (wie vorher)
    const double tiltThreshold = isMobile ? 7.0 : 6.0;
    const double neutralThreshold = isMobile ? 5.0 : 4.0;

    // Debug-Logging (nur alle 500ms um nicht zu spammen)
    if (kDebugMode && now.millisecondsSinceEpoch % 500 < 50) {
      const platform = isMobile ? '📱' : '🌐';
      debugPrint('$platform Sensor: x=${x.toStringAsFixed(1)}, y=${y.toStringAsFixed(1)}, z=${z.toStringAsFixed(1)} | Neutral: $_neutralPosition | Thresholds: tilt=$tiltThreshold, neutral=$neutralThreshold');
    }

    // Neutral Position erkennen
    if (y.abs() < neutralThreshold) {
      if (!_neutralPosition && kDebugMode) {
        debugPrint('✅ Neutral position restored');
      }
      _neutralPosition = true;
      return;
    }

    if (!_neutralPosition) return;

    // Kippen nach vorne (y > threshold) = Richtig
    if (y > tiltThreshold) {
      if (kDebugMode) {
        debugPrint('🟢 CORRECT detected! y=${y.toStringAsFixed(1)}');
      }
      _neutralPosition = false;
      _handleCorrect();
    }
    // Kippen nach hinten (y < -threshold) = Überspringen
    else if (y < -tiltThreshold) {
      if (kDebugMode) {
        debugPrint('🔴 PASS detected! y=${y.toStringAsFixed(1)}');
      }
      _neutralPosition = false;
      _handlePass();
    }
  }

  void _nextWord() {
    if (_currentWords.isEmpty) {
      _endGame();
      return;
    }
    setState(() {
      _currentWord = _currentWords.removeLast();
    });
  }

  void _handleCorrect() {
    if (!_canSkip) return;
    _canSkip = false;
    
    if (kDebugMode) {
      debugPrint('✅ CORRECT action triggered');
    }
    
    setState(() {
      _score++;
      _results.add({'word': _currentWord, 'correct': true});
    });

    // Haptic + Sound + Feedback in perfekter Synchronisation
    HapticFeedback.heavyImpact();
    
    // Sound-Aufruf non-blocking für bessere Performance
    context.read<SoundService>().playCorrect().then((_) {
      if (kDebugMode) {
        debugPrint('🔊 Correct sound played');
      }
    }).catchError((e) {
      if (kDebugMode) {
        debugPrint('⚠️ Sound error: $e');
      }
    });
    
    _showFeedback(
      const Color(0xDD10B981), // Grün mit höherer Deckkraft für bessere Sichtbarkeit
      onFinished: () {
        _nextWord();
        _canSkip = true;
        if (kDebugMode) {
          debugPrint('🔄 Ready for next word');
        }
      },
    );
  }

  void _handlePass() {
    if (!_canSkip) return;
    _canSkip = false;
    
    if (kDebugMode) {
      debugPrint('➡️ PASS action triggered');
    }
    
    setState(() {
      _results.add({'word': _currentWord, 'correct': false});
    });

    // Sound für 'Pass' bewusst softer (kein Haptic Feedback)
    context.read<SoundService>().playWrong().then((_) {
      if (kDebugMode) {
        debugPrint('🔊 Wrong sound played');
      }
    }).catchError((e) {
      if (kDebugMode) {
        debugPrint('⚠️ Sound error: $e');
      }
    });
    
    _showFeedback(
      const Color(0xCCEF4444), // Rot mit etwas geringerer Deckkraft (softer)
      onFinished: () {
        _nextWord();
        _canSkip = true;
        if (kDebugMode) {
          print('🔄 Ready for next word');
        }
      },
    );
  }
  
  void _showFeedback(Color color, {VoidCallback? onFinished}) {
    setState(() => _feedbackColor = color);
    _feedbackTimer?.cancel();
    _feedbackTimer = Timer(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() => _feedbackColor = null);
        onFinished?.call();
      }
    });
  }

  void _endGame() {
    _gameTimer?.cancel();
    _accelerometerSubscription?.cancel();
    context.read<SoundService>().playEnd();
    
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    setState(() {
      _gameState = StirnratenGameState.result;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ModernBackground(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    switch (_gameState) {
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
              '$_countdown',
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

  Widget _buildSetup() {
    return SafeArea(
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
              child: Column(
                children: [
                  const Text(
                    'Stirnraten',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Wähle eine Kategorie',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: Color(0x8CFFFFFF),
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 1.0,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final category = StirnratenCategory.values[index];
                  final colors = _getCategoryGradient(category);
                  return _CategoryCard(
                    title: StirnratenData.categoryNames[category]!,
                    gradientColors: colors,
                    onTap: () => _startCountdown(category),
                  );
                },
                childCount: StirnratenCategory.values.length,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Text(
                    '← Zurück',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0x8CFFFFFF),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Color> _getCategoryGradient(StirnratenCategory category) {
    switch (category) {
      case StirnratenCategory.anime:
        return [const Color(0xFFEF4444), const Color(0xFFF59E0B)];
      case StirnratenCategory.starWars:
        return [const Color(0xFFF59E0B), const Color(0xFFF1C40F)];
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
        return [const Color(0xFFF59E0B), const Color(0xFFFBBF24)];
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
        return [const Color(0xFFF59E0B), const Color(0xFFFCD34D)];
      case StirnratenCategory.household:
        return [const Color(0xFF6B7280), const Color(0xFF9CA3AF)];
      case StirnratenCategory.bodyParts:
        return [const Color(0xFFEC4899), const Color(0xFFF472B6)];
      case StirnratenCategory.books:
        return [const Color(0xFF8B5CF6), const Color(0xFFA78BFA)];
      case StirnratenCategory.cities:
        return [const Color(0xFF3B82F6), const Color(0xFF60A5FA)];
      case StirnratenCategory.festivals:
        return [const Color(0xFFF59E0B), const Color(0xFFFCD34D)];
      case StirnratenCategory.feelings:
        return [const Color(0xFFEF4444), const Color(0xFFF87171)];
      default:
        return [const Color(0xFF3B82F6), const Color(0xFF2563EB)];
    }
  }

  Widget _buildGame() {
    return Stack(
      children: [
        Container(
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
              _currentWord,
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
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(20),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withAlpha(40),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  '$_timeLeft',
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

        const Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Text(
            'Tippen oder kippen',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0x80FFFFFF),
              fontSize: 14,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
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
                '$_score',
                style: const TextStyle(
                  fontSize: 72,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFF59E0B),
                  letterSpacing: -2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _score == 1 ? 'Punkt' : 'Punkte',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withAlpha(140),
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 48),
              if (_results.isNotEmpty)
                GlassCard(
                  child: Column(
                    children: [
                      ...List.generate(_results.length.clamp(0, 10), (index) {
                        final result = _results[index];
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: index < _results.length - 1 ? 16 : 0,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                result['correct']
                                    ? Icons.check_circle
                                    : Icons.cancel,
                                color: result['correct']
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFEF4444),
                                size: 24,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  result['word'],
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
                      if (_results.length > 10) ...[
                        const SizedBox(height: 16),
                        Text(
                          '+ ${_results.length - 10} weitere',
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
                  Color(0xFFEF4444),
                  Color(0xFFF59E0B),
                ],
                onPressed: () {
                  setState(() {
                    _gameState = StirnratenGameState.setup;
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

class _CategoryCard extends StatefulWidget {
  final String title;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.title,
    required this.gradientColors,
    required this.onTap,
  });

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    widget.gradientColors[0].withAlpha(51),
                    widget.gradientColors[1].withAlpha(26),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: widget.gradientColors[0].withAlpha(102),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
