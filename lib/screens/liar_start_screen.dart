import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/game_service.dart';
import '../utils/theme.dart';
import '../widgets/glass_widgets.dart';
import 'lobby_screen.dart';
import 'join_room_screen.dart';

class LiarStartScreen extends StatefulWidget {
  const LiarStartScreen({super.key});

  @override
  State<LiarStartScreen> createState() => _LiarStartScreenState();
}

class _LiarStartScreenState extends State<LiarStartScreen> with TickerProviderStateMixin {
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
                color: Color.fromRGBO(239,68,68,0.2),
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
      body: ModernBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                  child: Column(
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
                      const SizedBox(height: 32),
                      _buildHowToPlay(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withAlpha(40),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFA855F7), Color(0xFFEC4899)],
            ),
            borderRadius: BorderRadius.circular(28),
          ),
          child: const Center(
            child: Text(
              '🎭',
              style: TextStyle(fontSize: 48),
            ),
          ),
        ),
        const SizedBox(height: 24),
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFA855F7), Color(0xFFEC4899)],
          ).createShader(bounds),
          child: const Text(
            'LÜGNER',
            style: TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 6,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Finde den Lügner',
          style: TextStyle(
            color: Colors.white.withAlpha(140),
            fontSize: 15,
            fontWeight: FontWeight.w400,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildNameCard() {
    return GlassCard(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFA855F7), Color(0xFFEC4899)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.person, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Dein Name',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          GlassTextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            hintText: 'Wie heißt du?',
            onSubmitted: (_) => _createRoom(),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateRoomButton() {
    return GlassButton(
      text: _isCreatingRoom ? 'Wird erstellt...' : 'Raum erstellen',
      isFullWidth: true,
      gradientColors: const [Color(0xFFA855F7), Color(0xFFEC4899)],
      onPressed: _isCreatingRoom ? null : _createRoom,
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: Colors.white.withAlpha(26),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'ODER',
            style: TextStyle(
              color: Colors.white.withAlpha(128),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 2,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            color: Colors.white.withAlpha(26),
          ),
        ),
      ],
    );
  }

  Widget _buildJoinRoomButton() {
    return GlassButton(
      text: 'Raum beitreten',
      isFullWidth: true,
      isPrimary: false,
      onPressed: () {
        final name = _nameController.text.trim();
        if (name.isEmpty) {
          _showError('Bitte gib zuerst deinen Namen ein');
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => JoinRoomScreen(playerName: name),
          ),
        );
      },
    );
  }

  Widget _buildHowToPlay() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF06B6D4), Color(0xFF3B82F6)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.lightbulb_outline,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'So funktioniert\'s',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildStep(1, 'Alle bekommen dieselbe Frage...', 'nur einer nicht!',
              const Color(0xFFA855F7),),
          _buildStep(2, 'Der Lügner muss sich', 'unauffällig verhalten',
              const Color(0xFFEC4899),),
          _buildStep(3, 'Alle antworten, dann', 'wird abgestimmt',
              const Color(0xFF06B6D4),),
          _buildStep(4, 'Finde den Lügner oder', 'überlebe als Lügner!',
              const Color(0xFF10B981), isLast: true,),
        ],
      ),
    );
  }

  Widget _buildStep(int number, String line1, String line2, Color color,
      {bool isLast = false,}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                '$number',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                ),
                Text(
                  line2,
                  style: TextStyle(
                    color: Colors.white.withAlpha(140),
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.2,
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
