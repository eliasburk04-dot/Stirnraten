import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/game_service.dart';
import 'lobby_screen.dart';
import 'join_room_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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
      _showError('Please enter your name');
      return;
    }

    if (name.length < 2) {
      _showError('Name must be at least 2 characters');
      return;
    }

    setState(() => _isCreatingRoom = true);

    final gameService = context.read<GameService>();
    final success = await gameService.createRoom(name);

    setState(() => _isCreatingRoom = false);

    if (success && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LobbyScreen()),
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
        backgroundColor: Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.3),
              Theme.of(context).colorScheme.surface,
              Theme.of(context).colorScheme.secondary.withOpacity(0.2),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo/Title
                  _buildLogo(),
                  const SizedBox(height: 48),
                  
                  // Name Input Card
                  _buildNameCard(),
                  const SizedBox(height: 24),
                  
                  // Create Room Button
                  _buildCreateRoomButton(),
                  const SizedBox(height: 16),
                  
                  // Divider
                  _buildDivider(),
                  const SizedBox(height: 16),
                  
                  // Join Room Button
                  _buildJoinRoomButton(),
                  const SizedBox(height: 32),
                  
                  // How to Play
                  _buildHowToPlay(),
                ],
              ),
            ),
          ),
        ),
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
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(
            Icons.psychology_alt,
            size: 60,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'LÜGNER',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 8,
                color: Colors.white,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'The Liar Game',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white70,
                letterSpacing: 2,
              ),
        ),
      ],
    );
  }

  Widget _buildNameCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter Your Name',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: 'Your name',
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
              ),
              onSubmitted: (_) => _createRoom(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateRoomButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _isCreatingRoom ? null : _createRoom,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
        ),
        icon: _isCreatingRoom
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : const Icon(Icons.add_circle_outline),
        label: Text(
          _isCreatingRoom ? 'Creating...' : 'Create Room',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.white24)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'OR',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white54,
                ),
          ),
        ),
        Expanded(child: Divider(color: Colors.white24)),
      ],
    );
  }

  Widget _buildJoinRoomButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton.icon(
        onPressed: () {
          final name = _nameController.text.trim();
          if (name.isEmpty) {
            _showError('Please enter your name first');
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
          side: BorderSide(color: Theme.of(context).colorScheme.primary),
        ),
        icon: const Icon(Icons.login),
        label: const Text(
          'Join Room',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildHowToPlay() {
    return Card(
      color: Theme.of(context).colorScheme.surface.withOpacity(0.5),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.help_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'How to Play',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildHowToPlayItem(
              '1',
              'All players receive the same question... except one!',
            ),
            _buildHowToPlayItem(
              '2',
              'The "Liar" gets a different question but must blend in.',
            ),
            _buildHowToPlayItem(
              '3',
              'Everyone answers, then votes on who had a different question.',
            ),
            _buildHowToPlayItem(
              '4',
              'Catch the Liar to win, or survive as the Liar!',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHowToPlayItem(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white70,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
