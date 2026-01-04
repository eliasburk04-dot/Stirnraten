import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'liar_start_screen.dart';
import 'stirnraten_screen.dart';
import 'bomb_party_start_screen.dart';
import 'lobby_screen.dart';
import '../services/game_service.dart';
import '../services/sound_service.dart';

class GameData {
  final String title;
  final String description;
  final String? imagePath;
  final String emoji;
  final List<Color> gradientColors;
  final Widget screen;

  GameData({
    required this.title,
    required this.description,
    this.imagePath,
    required this.emoji,
    required this.gradientColors,
    required this.screen,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late PageController _pageController;
  int _currentPage = 0;

  late final List<GameData> _games;
  late AnimationController _backgroundAnimController;

  @override
  void initState() {
    super.initState();
    _games = [
      GameData(
        title: 'Stirnraten',
        description: 'Rate das Wort auf deiner Stirn mit Hilfe deiner Freunde.',
        imagePath: 'assets/images/stirnraten_image.png',
        emoji: '🤔',
        gradientColors: const [Color(0xFFEF4444), Color(0xFFF59E0B)],
        screen: const StirnratenScreen(),
      ),
      GameData(
        title: 'Lügner',
        description: 'Finde den Lügner! Ein Spieler kennt das Geheimnis nicht.',
        imagePath: 'assets/images/Lügner_image.png',
        emoji: '🎭',
        gradientColors: const [Color(0xFF7C3AED), Color(0xFFEC4899)],
        screen: const LiarStartScreen(),
      ),
      GameData(
        title: 'Bomb Party',
        description: 'Finde schnell ein Wort mit der Silbe, bevor die Bombe explodiert!',
        imagePath: 'assets/images/bomb_party.png',
        emoji: '💣',
        gradientColors: const [Color(0xFFF59E0B), Color(0xFFEF4444)],
        screen: const BombPartyStartScreen(),
      ),
    ];

    _pageController = PageController(viewportFraction: 0.75);
    
    _backgroundAnimController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat(reverse: true);

    // Check for room code in URL (Web only)
    if (kIsWeb) {
      _checkForRoomCode();
    }
  }

  void _checkForRoomCode() {
    if (!kIsWeb) return;
    
    final uri = Uri.base;
    String? code = uri.queryParameters['code'];
    
    // If not in main query, check fragment (Flutter often puts query after #)
    if (code == null && uri.hasFragment) {
      final fragment = uri.fragment;
      if (fragment.contains('code=')) {
        try {
          // Extract code from fragment like "/?code=ABCDEF" or "join?code=ABCDEF"
          final regExp = RegExp(r'code=([A-Z0-9]{6})');
          final match = regExp.firstMatch(fragment);
          if (match != null) {
            code = match.group(1);
          }
        } catch (e) {
          debugPrint('Error parsing fragment for code: $e');
        }
      }
    }
    
    if (code != null && code.length == 6) {
      // Use a small delay to ensure the UI is ready
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          _showJoinWithCodeDialog(code!);
        }
      });
    }
  }

  void _showJoinWithCodeDialog(String code) {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Raum beitreten', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Du wurdest eingeladen, dem Raum $code beizutreten.', 
              style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 20),
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Dein Name',
                hintStyle: TextStyle(color: Colors.white30),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                final gameService = context.read<GameService>();
                final success = await gameService.joinRoom(code, name);
                if (!mounted) return;
                
                if (success) {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const LobbyScreen()));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(gameService.errorMessage ?? 'Fehler beim Beitreten'))
                  );
                }
              }
            },
            child: const Text('Beitreten'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _backgroundAnimController.dispose();
    super.dispose();
  }

  void _onGameSelected(int index) {
    context.read<SoundService>().playClick();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => _games[index].screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: Stack(
        children: [
          // 1. Dynamic Background
          _buildAnimatedBackground(),
          
          // 2. Content
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                Expanded(
                  child: AnimatedBuilder(
                    animation: _pageController,
                    builder: (context, child) {
                      double page = 0.0;
                      if (_pageController.hasClients) {
                        page = _pageController.page ?? 0.0;
                      }
                      return Column(
                        children: [
                          Expanded(
                            child: PageView.builder(
                              controller: _pageController,
                              onPageChanged: (index) {
                                setState(() => _currentPage = index);
                                HapticFeedback.selectionClick();
                              },
                              itemCount: _games.length,
                              physics: const BouncingScrollPhysics(),
                              itemBuilder: (context, index) {
                                return _buildGameCard(index, page);
                              },
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildPageIndicators(page),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    final currentColors = _games[_currentPage].gradientColors;
    
    return RepaintBoundary(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0F0F1A),
              currentColors[0].withOpacity(0.4),
              currentColors[1].withOpacity(0.2),
              const Color(0xFF0F0F1A),
            ],
            stops: const [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: Container(color: Colors.transparent),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Let\'s Play',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Choose a Game',
            style: GoogleFonts.poppins(
              fontSize: 28,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameCard(int index, double pageValue) {
    double percent = (pageValue - index);
    double scale = (1 - (percent.abs() * 0.1)).clamp(0.85, 1.0);
    double opacity = (1 - (percent.abs() * 0.5)).clamp(0.5, 1.0);
    double verticalOffset = percent.abs() * 20;

    final game = _games[index];

    return RepaintBoundary(
      child: Transform.translate(
        offset: Offset(0, verticalOffset),
        child: Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: opacity,
            child: GestureDetector(
              onTap: () => _onGameSelected(index),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: game.gradientColors[0].withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                      spreadRadius: -5,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // 1. Full Screen Illustration/Background
                      _buildGameIllustration(game),

                      // 2. Glass/Gradient Overlay for Text Readability
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.0),
                                Colors.black.withOpacity(0.6),
                                Colors.black.withOpacity(0.9),
                              ],
                              stops: const [0.0, 0.4, 0.7, 1.0],
                            ),
                          ),
                        ),
                      ),
                      
                      // 3. Card Content (Text & Button)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                game.title,
                                style: GoogleFonts.poppins(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  height: 1.1,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withOpacity(0.5),
                                      blurRadius: 10,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                game.description,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.9),
                                  height: 1.5,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withOpacity(0.5),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 24),
                              _buildPlayButton(game),
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
        ),
      ),
    );
  }

  Widget _buildGameIllustration(GameData game) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background Gradient
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                game.gradientColors[0].withOpacity(0.6),
                game.gradientColors[1].withOpacity(0.4),
              ],
            ),
          ),
        ),
        
        // Decorative Circles
        Positioned(
          top: -50,
          right: -50,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: game.gradientColors[1].withOpacity(0.3),
              boxShadow: [
                BoxShadow(
                  color: game.gradientColors[1].withOpacity(0.5),
                  blurRadius: 60,
                  spreadRadius: 10,
                ),
              ],
            ),
          ),
        ),

        // Main Image or Emoji
        if (game.imagePath != null)
          Image.asset(
            game.imagePath!,
            fit: BoxFit.cover,
            errorBuilder: (c, o, s) => Center(child: _buildEmoji(game)),
          )
        else
          Center(child: _buildEmoji(game)),
      ],
    );
  }

  Widget _buildEmoji(GameData game) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: game.gradientColors[0].withOpacity(0.5),
            blurRadius: 60,
            spreadRadius: -10,
          ),
        ],
      ),
      child: Text(
        game.emoji,
        style: const TextStyle(fontSize: 80),
      ),
    );
  }

  Widget _buildPlayButton(GameData game) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: game.gradientColors,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: game.gradientColors[0].withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Center(
        child: Text(
          'PLAY NOW',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }

  Widget _buildPageIndicators(double pageValue) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_games.length, (index) {
        double selectedness = (1 - (pageValue - index).abs()).clamp(0.0, 1.0);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 8,
          width: 8 + (16 * selectedness),
          decoration: BoxDecoration(
            color: Color.lerp(
              Colors.white24,
              _games[index].gradientColors[0],
              selectedness,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
