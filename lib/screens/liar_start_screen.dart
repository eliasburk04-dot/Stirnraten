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
  bool _isHowToPlayExpanded = false;
  bool _specialRolesEnabled = false;
  int _selectedLiarCount = 1;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _nameController.dispose();
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
    final success = await gameService.createRoom(
      name, 
      liarCount: _selectedLiarCount,
      specialRolesEnabled: _specialRolesEnabled,
    );

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
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFA855F7), Color(0xFFEC4899)],
            ),
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFEC4899).withAlpha(60),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: Image.asset(
              'assets/images/Lügner_image.png',
              fit: BoxFit.cover,
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
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Anzahl Lügner:',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: DropdownButton<int>(
                  value: _selectedLiarCount,
                  dropdownColor: const Color(0xFF1E293B),
                  underline: const SizedBox(),
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  items: [1, 2, 3].map((int value) {
                    return DropdownMenuItem<int>(
                      value: value,
                      child: Text('$value'),
                    );
                  }).toList(),
                  onChanged: (int? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedLiarCount = newValue;
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSpecialRolesToggle(),
        ],
      ),
    );
  }

  Widget _buildSpecialRolesToggle() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Spezialrollen:',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'Detektiv & Komplize',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            Switch.adaptive(
              value: _specialRolesEnabled,
              activeColor: AppTheme.primaryPurple,
              onChanged: (value) {
                setState(() {
                  _specialRolesEnabled = value;
                });
              },
            ),
          ],
        ),
        if (_specialRolesEnabled) ...[
          const SizedBox(height: 12),
          _buildRoleDescription(
            '🕵️', 
            'Detektiv', 
            'Erhält einen Hinweis, dass die Fragen unterschiedlich sind (aber nicht die Lügner-Frage).',
            const Color(0xFF3B82F6),
          ),
          const SizedBox(height: 8),
          _buildRoleDescription(
            '🤝', 
            'Komplize', 
            'Lügner wissen bei mehreren Lügnern voneinander.',
            const Color(0xFFEF4444),
          ),
        ],
      ],
    );
  }

  Widget _buildRoleDescription(String emoji, String title, String desc, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  desc,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
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
          GestureDetector(
            onTap: () => setState(() => _isHowToPlayExpanded = !_isHowToPlayExpanded),
            behavior: HitTestBehavior.opaque,
            child: Row(
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
                    Icons.menu_book_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Spielanleitung',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                AnimatedRotation(
                  duration: const Duration(milliseconds: 300),
                  turns: _isHowToPlayExpanded ? 0.5 : 0,
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _isHowToPlayExpanded
                ? Column(
                    children: [
                      const SizedBox(height: 24),
                      _buildStep(
                        1,
                        'Geheimnis erhalten',
                        'Fast alle Spieler erhalten die gleiche Frage mit einer Zahl als Antwort. Nur die Lügner erhalten eine leicht andere Frage!',
                        const Color(0xFFA855F7),
                      ),
                      _buildStep(
                        2,
                        'Antworten geben',
                        'Jeder gibt seine Antwort ein. Als Lügner musst du schätzen, was die anderen gefragt wurden, um nicht aufzufallen.',
                        const Color(0xFFEC4899),
                      ),
                      _buildStep(
                        3,
                        'Diskussion & Voting',
                        'Vergleicht eure Antworten! Wer weicht extrem ab? Diskutiert und stimmt dann ab, wer der Lügner ist.',
                        const Color(0xFF06B6D4),
                      ),
                      _buildStep(
                        4,
                        'Sieg oder Niederlage',
                        'Wird der Lügner entlarvt, gewinnen die ehrlichen Spieler. Bleibt er unentdeckt, gewinnt der Lügner!',
                        const Color(0xFF10B981),
                        isLast: true,
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(int number, String title, String description, Color color,
      {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.5), width: 2),
            ),
            child: Center(
              child: Text(
                '$number',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w400,
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
