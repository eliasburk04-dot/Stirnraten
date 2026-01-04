import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/game_service.dart';
import '../models/game_state.dart';
import '../utils/theme.dart';
import '../widgets/glass_widgets.dart';
import 'lobby_screen.dart';
import 'join_room_screen.dart';

class BombPartyStartScreen extends StatefulWidget {
  const BombPartyStartScreen({super.key});

  @override
  State<BombPartyStartScreen> createState() => _BombPartyStartScreenState();
}

class _BombPartyStartScreenState extends State<BombPartyStartScreen> {
  final _nameController = TextEditingController();
  bool _isCreatingRoom = false;

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

    setState(() => _isCreatingRoom = true);

    final gameService = context.read<GameService>();
    final success = await gameService.createRoom(
      name, 
      gameType: GameType.bombParty,
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
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ModernBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Text(
                      'Bomb Party',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                Center(
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withAlpha(60),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(32),
                      child: Image.asset(
                        'assets/images/bomb_party.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                GlassCard(
                  child: Column(
                    children: [
                      const Text(
                        'Spiel erstellen',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _nameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Dein Name',
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.1),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isCreatingRoom ? null : _createRoom,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isCreatingRoom
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text(
                                  'RAUM ERSTELLEN',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Center(
                  child: Text(
                    'ODER',
                    style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
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
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'RAUM BEITRETEN',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                _buildHowToPlay(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHowToPlay() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'So wird gespielt:',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildStep('1', 'Jeder Spieler hat 3 Leben.'),
          _buildStep('2', 'Du bekommst eine Silbe (z.B. "EN").'),
          _buildStep('3', 'Finde ein Wort, das diese Silbe enthält (z.B. "ENTENTE").'),
          _buildStep('4', 'Sei schnell! Wenn die Bombe explodiert, verlierst du ein Leben.'),
          _buildStep('5', 'Der letzte Spieler mit Leben gewinnt!'),
        ],
      ),
    );
  }

  Widget _buildStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$number. ',
            style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}
