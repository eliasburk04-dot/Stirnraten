import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../services/sound_service.dart';
import '../services/category_service.dart';
import '../utils/sensor_helper.dart';
import '../data/words.dart';
import '../widgets/glass_widgets.dart';

const Color _categoryPrimary = Color(0xFFF9F506);
const Color _categoryBackground = Color(0xFF1A1A0F);
const Color _categorySurface = Color(0xFF23220F);
const Color _categoryGlass = Color(0x6623220F);
const Color _categoryBorder = Color(0x14FFFFFF);
const double _categoryCardRadius = 24;

enum StirnratenGameState { setup, countdown, playing, result }

class StirnratenScreen extends StatefulWidget {
  const StirnratenScreen({super.key});

  @override
  State<StirnratenScreen> createState() => _StirnratenScreenState();
}

class _StirnratenScreenState extends State<StirnratenScreen> {
  final CategoryService _categoryService = CategoryService();
  StirnratenGameState _gameState = StirnratenGameState.setup;
  final Set<StirnratenCategory> _selectedCategories = <StirnratenCategory>{};
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
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  String _searchQuery = '';
  late final List<_CategoryCardData> _categoryItems;

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
  }

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
    _searchController.dispose();
    _searchFocusNode.dispose();
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
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
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
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                            title: Text(cat.name, style: const TextStyle(color: Colors.white, fontSize: 14)),
                            subtitle: Text('${cat.words.length} Wörter', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
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
                        ),).toList(),
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
                backgroundColor: Colors.blue.withValues(alpha: 0.2),
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
              initialValue: _selectedTime,
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
                      ),)
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

  List<_CategoryCardData> _buildCategoryItems() {
    return StirnratenCategory.values.map((category) {
      final title = StirnratenData.categoryNames[category] ?? category.name;
      final wordCount = StirnratenData.getWords(category).length;
      final subtitle = category == StirnratenCategory.ownWords
          ? 'Custom lists'
          : '$wordCount+ words';
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
    const bottomBarHeight = 104.0;

    return DefaultTextStyle(
      style: GoogleFonts.spaceGrotesk(
        color: Colors.white,
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
                      onSettings: _showTimeSelectionDialog,
                      onQueryChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      20,
                      12,
                      20,
                      bottomBarHeight,
                    ),
                    sliver: SliverMasonryGrid.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
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
                              _showOwnWordsDialog();
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
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildLegacySetup() {
    return const SizedBox.shrink();
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
  bool _hovered = false;
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) {
      setState(() => _pressed = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.data.accentColor ?? _categoryPrimary;
    final borderColor = widget.isSelected
        ? _categoryPrimary
        : (_hovered
            ? Colors.white.withValues(alpha: 0.18)
            : _categoryBorder);
    final scale = _pressed ? 0.95 : (_hovered ? 1.02 : 1.0);
    final showGlow = widget.isSelected || _hovered;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_categoryCardRadius),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _categoryGlass,
                  borderRadius: BorderRadius.circular(_categoryCardRadius),
                  border: Border.all(
                    color: borderColor,
                    width: widget.isSelected ? 2 : 1,
                  ),
                  boxShadow: showGlow
                      ? [
                          BoxShadow(
                            color: accent.withValues(
                              alpha: widget.isSelected ? 0.35 : 0.18,
                            ),
                            blurRadius: 26,
                            offset: const Offset(0, 12),
                          ),
                        ]
                      : null,
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
                                  textColor: _categoryBackground,
                                ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.data.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.data.subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.6),
                        letterSpacing: 0.2,
                      ),
                    ),
                    if (widget.data.tags.isNotEmpty) ...[
                      const SizedBox(height: 10),
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
                      const SizedBox(height: 10),
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
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: accent.withValues(alpha: 0.45),
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: icon == null
          ? const SizedBox.shrink()
          : Icon(
              icon,
              color: Colors.white,
              size: 22,
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
        style: TextStyle(
          color: textColor,
          fontSize: 9,
          fontWeight: FontWeight.w700,
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
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withValues(alpha: 0.45),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w700,
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
              color: Colors.white.withValues(alpha: 0.08),
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
                        accent.withValues(alpha: 0.9),
                        accent.withValues(alpha: 0.45),
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
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 10,
              fontWeight: FontWeight.w700,
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
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                _categoryBackground.withValues(alpha: 0.0),
                _categoryBackground.withValues(alpha: 0.8),
                _categoryBackground,
              ],
            ),
          ),
          child: _PrimaryActionButton(
            label: 'Play ($selectedCount Selected)',
            onTap: onPressed,
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
    final isEnabled = widget.onTap != null;
    final backgroundColor =
        isEnabled ? _categoryPrimary : _categorySurface.withValues(alpha: 0.6);
    final foregroundColor =
        isEnabled ? _categoryBackground : Colors.white.withValues(alpha: 0.4);

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
          height: 56,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(999),
            boxShadow: isEnabled
                ? [
                    BoxShadow(
                      color: _categoryPrimary.withValues(alpha: 0.35),
                      blurRadius: 24,
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
                style: TextStyle(
                  color: foregroundColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              Positioned(
                right: 18,
                child: Icon(
                  Icons.play_arrow_rounded,
                  color: foregroundColor,
                  size: 22,
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

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          decoration: BoxDecoration(
            color: _categoryBackground.withValues(alpha: 0.9),
            boxShadow: showShadow
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 18,
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
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Stirnraten',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
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
        ),
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
        color: _categorySurface.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isFocused ? _categoryPrimary : Colors.white.withValues(alpha: 0.08),
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
            color: Colors.white.withValues(alpha: 0.5),
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: 'Search decks...',
                hintStyle: GoogleFonts.spaceGrotesk(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
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
  bool _hovered = false;
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
        : _categoryGlass;
    final borderColor = widget.isPrimary
        ? _categoryPrimary
        : Colors.white.withValues(alpha: 0.12);
    final iconColor = widget.isPrimary
        ? _categoryBackground
        : Colors.white.withValues(alpha: 0.85);
    final scale = _pressed ? 0.94 : (_hovered ? 1.03 : 1.0);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
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
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
              boxShadow: widget.isPrimary
                  ? [
                      BoxShadow(
                        color: _categoryPrimary.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              widget.icon,
              color: iconColor,
              size: 20,
            ),
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
    return Container(
      decoration: BoxDecoration(
        color: _categoryBackground,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _categoryBackground,
            _categorySurface.withValues(alpha: 0.45),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -80,
            right: -40,
            child: _GlowOrb(
              color: _categoryPrimary.withValues(alpha: 0.16),
              size: 240,
            ),
          ),
          Positioned(
            bottom: -120,
            left: -60,
            child: _GlowOrb(
              color: const Color(0xFF4ADE80).withValues(alpha: 0.16),
              size: 280,
            ),
          ),
          Positioned(
            top: 140,
            left: -90,
            child: _GlowOrb(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
              size: 220,
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

  const _GlowOrb({
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
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.6),
            blurRadius: 120,
            spreadRadius: 20,
          ),
        ],
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
