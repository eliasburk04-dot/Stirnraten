import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:provider/provider.dart';
import '../services/sound_service.dart';
import '../services/category_service.dart';
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
  final CategoryService _categoryService = CategoryService();
  StirnratenGameState _gameState = StirnratenGameState.setup;
  List<String> _currentWords = [];
  List<Map<String, dynamic>> _results = []; // {word: String, correct: bool}
  int _score = 0;
  int _selectedTime = 150;
  int _timeLeft = 150;
  int _countdown = 3;
  Timer? _gameTimer;
  Timer? _countdownTimer;
  String _currentWord = "";
  bool _initialCooldownActive = false;
  
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
    super.dispose();
  }

  void _showOwnWordsDialog() {
    final TextEditingController controller = TextEditingController();
    final TextEditingController nameController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('Eigene Wörter', style: TextStyle(color: Colors.white)),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Gib deine Wörter ein (getrennt durch Komma):',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Apfel, Birne, Banane...',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () async {
                        final text = controller.text;
                        if (text.isNotEmpty) {
                          final words = text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                          if (words.isNotEmpty) {
                            final name = await showDialog<String>(
                              context: context,
                              builder: (context) => AlertDialog(
                                backgroundColor: const Color(0xFF1E293B),
                                title: const Text('Liste speichern', style: TextStyle(color: Colors.white)),
                                content: TextField(
                                  controller: nameController,
                                  autofocus: true,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: const InputDecoration(
                                    hintText: 'Name der Liste (z.B. Obst)',
                                    hintStyle: TextStyle(color: Colors.white30),
                                  ),
                                ),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, nameController.text),
                                    child: const Text('Speichern'),
                                  ),
                                ],
                              ),
                            );

                            if (name != null && name.isNotEmpty) {
                              await _categoryService.saveCategory(name, words);
                              nameController.clear();
                              setDialogState(() {}); // Refresh list
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Liste gespeichert!'), duration: Duration(seconds: 1)),
                                );
                              }
                            }
                          }
                        }
                      },
                      icon: const Icon(Icons.save, size: 18),
                      label: const Text('Liste speichern'),
                      style: TextButton.styleFrom(foregroundColor: Colors.blue),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Gespeicherte Listen:',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  FutureBuilder<List<CustomCategory>>(
                    future: _categoryService.getCustomCategories(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Text('Keine gespeicherten Listen', style: TextStyle(color: Colors.white30, fontSize: 12));
                      }
                      return Column(
                        children: snapshot.data!.map((cat) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                            title: Text(cat.name, style: const TextStyle(color: Colors.white, fontSize: 14)),
                            subtitle: Text('${cat.words.length} Wörter', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.play_arrow, color: Colors.green, size: 20),
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _startCountdownWithWords(cat.words);
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                  onPressed: () async {
                                    await _categoryService.deleteCategory(cat.name);
                                    setDialogState(() {});
                                  },
                                ),
                              ],
                            ),
                            onTap: () {
                              controller.text = cat.words.join(', ');
                            },
                          ),
                        )).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.withOpacity(0.2),
                foregroundColor: Colors.blue,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final text = controller.text;
                if (text.isNotEmpty) {
                  final words = text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                  if (words.isNotEmpty) {
                    if (mounted) {
                      Navigator.pop(context);
                      _startCountdownWithWords(words);
                    }
                  }
                }
              },
              child: const Text('Starten'),
            ),
          ],
        ),
      ),
    );
  }

  void _showTimeSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Spielzeit wählen', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Wähle die Dauer der Runde in Sekunden:',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<int>(
              value: _selectedTime,
              dropdownColor: const Color(0xFF1E293B),
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white30),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue),
                ),
              ),
              items: List.generate(10, (index) => (index + 1) * 30)
                  .map((time) => DropdownMenuItem<int>(
                        value: time,
                        child: Text('$time Sekunden'),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedTime = value;
                  });
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
        ],
      ),
    );
  }

  void _startCountdown(StirnratenCategory category) {
    _startCountdownWithWords(StirnratenData.getWords(category));
  }

  void _startCountdownWithWords(List<String> words) async {
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
      _currentWords = List.from(words)..shuffle();
      _score = 0;
      _timeLeft = _selectedTime;
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
      _initialCooldownActive = true;
      _neutralPosition = true;
      _feedbackColor = null; // Reset any lingering feedback
    });

    context.read<SoundService>().playStart();
    _nextWord();
    _startTimer();
    _startSensors();

    // Start initial cooldown to prevent accidental skipping on start
    Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _initialCooldownActive = false;
        });
        if (kDebugMode) {
          debugPrint('🎮 Stirnraten: Initial cooldown finished');
        }
      }
    });
    
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
          debugPrint('📱 Platform: ${defaultTargetPlatform.name}');
        } catch (e) {
          debugPrint('⚠️ Platform detection failed: $e');
        }
      }
    }
    
    if (kIsWeb) {
      // Web: Use JavaScript-based tilt detection
      if (kDebugMode) {
        debugPrint('🌐 Using JavaScript tilt detection for Web');
      }
      startWebTiltDetection(() {
        if (_gameState == StirnratenGameState.playing && _canSkip && !_initialCooldownActive) {
          _handleCorrect();
        }
      }, () {
        if (_gameState == StirnratenGameState.playing && _canSkip && !_initialCooldownActive) {
          _handlePass();
        }
      });
    } else {
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
    }
    
    if (kDebugMode) {
      debugPrint('✅ Sensor listeners activated');
    }
  }

  void _processSensorData(double x, double y, double z) {
    if (_gameState != StirnratenGameState.playing || !_canSkip || _initialCooldownActive) return;

    // Throttle: Process sensor data max every 50ms
    final now = DateTime.now();
    if (now.difference(_lastSensorProcessing) < _sensorThrottle) return;
    _lastSensorProcessing = now;

    // Adaptive Thresholds: Mobile-Geräte haben oft andere Sensitivität
    const bool isMobile = !kIsWeb;
    
    // Mobile: Etwas höhere Thresholds für stabilere Erkennung
    // Web: Niedrigere Thresholds (wie vorher)
    const double tiltThreshold = isMobile ? 7.0 : 5.0;
    const double neutralThreshold = isMobile ? 5.0 : 3.0;

    // Web verwendet X-Achse im Landscape, Mobile verwendet Y-Achse
    // Web: accelerationIncludingGravity hat andere Vorzeichen
    final double tiltValue = kIsWeb ? -x : y;

    // Debug-Logging (nur alle 500ms um nicht zu spammen)
    if (kDebugMode && now.millisecondsSinceEpoch % 500 < 50) {
      const platform = isMobile ? '📱' : '🌐';
      debugPrint('$platform Sensor: x=${x.toStringAsFixed(1)}, y=${y.toStringAsFixed(1)}, z=${z.toStringAsFixed(1)} | tiltValue=${tiltValue.toStringAsFixed(1)} | Neutral: $_neutralPosition');
    }

    // Neutral Position erkennen
    if (tiltValue.abs() < neutralThreshold) {
      if (!_neutralPosition && kDebugMode) {
        debugPrint('✅ Neutral position restored');
      }
      _neutralPosition = true;
      return;
    }

    if (!_neutralPosition) return;

    // Kippen nach vorne (tiltValue > threshold) = Richtig
    if (tiltValue > tiltThreshold) {
      if (kDebugMode) {
        debugPrint('🟢 CORRECT detected! tiltValue=${tiltValue.toStringAsFixed(1)}');
      }
      _neutralPosition = false;
      _handleCorrect();
    }
    // Kippen nach hinten (tiltValue < -threshold) = Überspringen
    else if (tiltValue < -tiltThreshold) {
      if (kDebugMode) {
        debugPrint('🔴 PASS detected! tiltValue=${tiltValue.toStringAsFixed(1)}');
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
    if (!_canSkip || _initialCooldownActive) return;
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
    if (!_canSkip || _initialCooldownActive) return;
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
    
    if (kIsWeb) {
      stopWebTiltDetection();
    }
    
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
      backgroundColor: const Color(0xFF0A0A12),
      resizeToAvoidBottomInset: false,
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
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withAlpha(60),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(32),
                      child: Image.asset(
                        'assets/images/stirnraten_image.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
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
                  const SizedBox(height: 20),
                  // Time Selection
                  GestureDetector(
                    onTap: () => _showTimeSelectionDialog(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.timer_outlined, color: Colors.white70, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Zeit: $_selectedTime Sek.',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_drop_down, color: Colors.white70),
                        ],
                      ),
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
                    icon: StirnratenData.categoryIcons[category]!,
                    gradientColors: colors,
                    onTap: () {
                      if (category == StirnratenCategory.ownWords) {
                        _showOwnWordsDialog();
                      } else {
                        _startCountdown(category);
                      }
                    },
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
      case StirnratenCategory.ownWords:
        return [const Color(0xFF8B5CF6), const Color(0xFFEC4899)];
      default:
        return [const Color(0xFF3B82F6), const Color(0xFF2563EB)];
    }
  }

  Widget _buildGame() {
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
          child: RepaintBoundary(
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
  final IconData icon;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.title,
    required this.icon,
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
              child: Stack(
                children: [
                  // Background Icon
                  Positioned(
                    right: -10,
                    bottom: -10,
                    child: Icon(
                      widget.icon,
                      size: 60,
                      color: Colors.white.withOpacity(0.15),
                    ),
                  ),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            widget.icon,
                            color: Colors.white.withOpacity(0.9),
                            size: 28,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.title,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
