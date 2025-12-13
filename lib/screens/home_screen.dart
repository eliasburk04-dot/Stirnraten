import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/game_service.dart';
import '../utils/theme.dart';
import '../widgets/animated_widgets.dart';
import 'lobby_screen.dart';
import 'join_room_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final _nameController = TextEditingController();
  bool _isCreatingRoom = false;
  late AnimationController _floatController;
  late AnimationController _rotateController;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);
    _rotateController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _floatController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  Future<void> _createRoom() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showError('Bitte gib deinen Namen ein');
      return;
    }

    if (name.length < 2) {
      _showError('Name muss mindestens 2 Zeichen haben');
      return;
    }

    setState(() => _isCreatingRoom = true);

    final gameService = context.read<GameService>();
    final success = await gameService.createRoom(name);

    setState(() => _isCreatingRoom = false);

    if (success && mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const LobbyScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    } else if (gameService.errorMessage != null && mounted) {
      _showError(gameService.errorMessage!);
      gameService.clearError();
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.accentRed.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline, color: AppTheme.accentRed, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppTheme.cardDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: Stack(
          children: [
            _buildBackgroundEffects(),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildLogo(),
                      const SizedBox(height: 48),
                      _buildNameCard(),
                      const SizedBox(height: 24),
                      _buildCreateRoomButton(),
                      const SizedBox(height: 16),
                      _buildDivider(),
                      const SizedBox(height: 16),
                      _buildJoinRoomButton(),
                      const SizedBox(height: 40),
                      _buildHowToPlay(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundEffects() {
    return Stack(
      children: [
        Positioned(
          top: -100,
          right: -100,
          child: AnimatedBuilder(
            animation: _rotateController,
            builder: (context, child) {
              return Transform.rotate(
                angle: _rotateController.value * 2 * math.pi,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        AppTheme.primaryPurple.withOpacity(0.3),
                        Colors.transparent,
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
              );
            },
          ),
        ),
        Positioned(
          bottom: -50,
          left: -50,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  AppTheme.primaryPink.withOpacity(0.2),
                  Colors.transparent,
                ],
              ),
              shape: BoxShape.circle,
            ),
          ),
        ),
        ...List.generate(6, (index) {
          return Positioned(
            left: (index * 60.0) + 20,
            top: 100 + (index * 80.0),
            child: FloatingParticle(
              color: index.isEven ? AppTheme.primaryPurple : AppTheme.primaryPink,
              size: 4 + (index * 2).toDouble(),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildLogo() {
    return FadeSlideTransition(
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _floatController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, math.sin(_floatController.value * math.pi) * 8),
                child: child,
              );
            },
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryPurple.withOpacity(0.5),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.psychology_alt,
                    size: 64,
                    color: Colors.white.withOpacity(0.9),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppTheme.accentOrange,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.question_mark,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          GradientText(
            text: 'LÜGNER',
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontSize: 42,
                  letterSpacing: 8,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Finde den Lügner',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white.withOpacity(0.6),
                  letterSpacing: 2,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameCard() {
    return FadeSlideTransition(
      delay: const Duration(milliseconds: 200),
      child: GlassCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.person, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'Dein Name',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(fontSize: 16),
              decoration: InputDecoration(
                hintText: 'Wie heißt du?',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                prefixIcon: Icon(
                  Icons.badge_outlined,
                  color: Colors.white.withOpacity(0.5),
                ),
              ),
              onSubmitted: (_) => _createRoom(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateRoomButton() {
    return FadeSlideTransition(
      delay: const Duration(milliseconds: 300),
      child: SizedBox(
        width: double.infinity,
        child: GradientButton(
          text: _isCreatingRoom ? 'Wird erstellt...' : 'Raum erstellen',
          icon: Icons.add_circle_outline,
          isLoading: _isCreatingRoom,
          onPressed: _isCreatingRoom ? null : _createRoom,
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return FadeSlideTransition(
      delay: const Duration(milliseconds: 350),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.white.withOpacity(0.2),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.cardDark,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Text(
                'ODER',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.2),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJoinRoomButton() {
    return FadeSlideTransition(
      delay: const Duration(milliseconds: 400),
      child: SizedBox(
        width: double.infinity,
        child: GestureDetector(
          onTap: () {
            final name = _nameController.text.trim();
            if (name.isEmpty) {
              _showError('Bitte gib zuerst deinen Namen ein');
              return;
            }
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    JoinRoomScreen(playerName: name),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  return SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(1, 0),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    )),
                    child: child,
                  );
                },
              ),
            );
          },
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.primaryPurple.withOpacity(0.5),
                width: 2,
              ),
            ),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.login,
                    color: AppTheme.primaryPurple.withOpacity(0.9),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Raum beitreten',
                    style: TextStyle(
                      color: AppTheme.primaryPurple.withOpacity(0.9),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
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

  Widget _buildHowToPlay() {
    return FadeSlideTransition(
      delay: const Duration(milliseconds: 500),
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.accentCyan.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.lightbulb_outline,
                    color: AppTheme.accentCyan,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'So funktioniert\'s',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildStep(1, 'Alle bekommen dieselbe Frage...', 'nur einer nicht!',
                AppTheme.primaryPurple),
            _buildStep(2, 'Der Lügner muss sich', 'unauffällig verhalten',
                AppTheme.primaryPink),
            _buildStep(3, 'Alle antworten, dann', 'wird abgestimmt',
                AppTheme.accentCyan),
            _buildStep(4, 'Finde den Lügner oder', 'überlebe als Lügner!',
                AppTheme.accentGreen, isLast: true),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(int number, String line1, String line2, Color color,
      {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withOpacity(0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                '$number',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line1,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  line2,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 13,
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
