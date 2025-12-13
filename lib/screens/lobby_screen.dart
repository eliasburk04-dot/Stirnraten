import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/game_service.dart';
import '../models/models.dart';
import '../utils/theme.dart';
import '../widgets/animated_widgets.dart';
import 'game_screen.dart';
import 'home_screen.dart';

class LobbyScreen extends StatelessWidget {
  const LobbyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<GameService>(
      builder: (context, gameService, child) {
        final room = gameService.currentRoom;
        final isHost = gameService.isHost;

        if (room != null && room.state != GameState.lobby) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    const GameScreen(),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
              ),
            );
          });
        }

        if (room == null) {
          return Scaffold(
            body: Container(
              decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
              child: const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryPurple),
              ),
            ),
          );
        }

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            final shouldLeave = await _showLeaveDialog(context);
            if (shouldLeave && context.mounted) {
              await gameService.leaveRoom();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const HomeScreen()),
              );
            }
          },
          child: Scaffold(
            body: Container(
              decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
              child: SafeArea(
                child: Column(
                  children: [
                    _buildAppBar(context, gameService),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildRoomCodeCard(context, room.code),
                            const SizedBox(height: 20),
                            _buildPlayersCard(context, room, gameService),
                            const SizedBox(height: 24),
                            if (isHost)
                              _buildStartButton(context, room, gameService)
                            else
                              _buildWaitingMessage(context),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppBar(BuildContext context, GameService gameService) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () async {
              final shouldLeave = await _showLeaveDialog(context);
              if (shouldLeave && context.mounted) {
                await gameService.leaveRoom();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const HomeScreen()),
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_back, color: Colors.white),
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Warteraum',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                'Warte auf Mitspieler...',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<bool> _showLeaveDialog(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppTheme.cardDark,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.accentRed.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.exit_to_app, color: AppTheme.accentRed),
                ),
                const SizedBox(width: 12),
                const Text('Raum verlassen?'),
              ],
            ),
            content: const Text('Bist du sicher, dass du den Raum verlassen möchtest?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Abbrechen',
                  style: TextStyle(color: Colors.white.withOpacity(0.7)),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentRed,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Verlassen'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Widget _buildRoomCodeCard(BuildContext context, String code) {
    return FadeSlideTransition(
      child: AnimatedGradientBorder(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.vpn_key, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Raum-Code',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white.withOpacity(0.8),
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: code));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppTheme.accentGreen.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check, color: AppTheme.accentGreen, size: 16),
                          ),
                          const SizedBox(width: 12),
                          const Text('Code kopiert!'),
                        ],
                      ),
                      backgroundColor: AppTheme.cardDark,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceDark,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.primaryPurple.withOpacity(0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GradientText(
                        text: code,
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 10,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryPurple.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.copy,
                          color: AppTheme.primaryPurple,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: QrImageView(
                  data: code,
                  version: QrVersions.auto,
                  size: 140,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: AppTheme.backgroundDark,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: AppTheme.backgroundDark,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Scanne oder teile den Code',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayersCard(BuildContext context, Room room, GameService gameService) {
    final isHost = gameService.isHost;

    return FadeSlideTransition(
      delay: const Duration(milliseconds: 200),
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.accentCyan.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.people, color: AppTheme.accentCyan, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Spieler',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
                AnimatedCounter(
                  value: room.players.length,
                  total: room.maxPlayers,
                  label: room.canStart ? 'Bereit!' : 'Min. ${room.minPlayers}',
                  color: room.canStart ? AppTheme.accentGreen : AppTheme.accentOrange,
                ),
              ],
            ),
            if (!room.canStart) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.accentOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.accentOrange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppTheme.accentOrange, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Mindestens ${room.minPlayers} Spieler benötigt',
                      style: const TextStyle(
                        color: AppTheme.accentOrange,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            ...room.players.asMap().entries.map((entry) {
              final index = entry.key;
              final player = entry.value;
              return _buildPlayerTile(
                context,
                player,
                isHost && player.id != room.hostId,
                () => gameService.kickPlayer(player.id),
                delay: Duration(milliseconds: 100 * index),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerTile(
    BuildContext context,
    Player player,
    bool canKick,
    VoidCallback onKick, {
    Duration delay = Duration.zero,
  }) {
    return FadeSlideTransition(
      delay: delay,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            PlayerAvatar(
              name: player.name,
              color: player.avatarColor,
              size: 44,
              isHost: player.isHost,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    player.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  if (player.isHost)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'HOST',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (canKick)
              GestureDetector(
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: AppTheme.cardDark,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      title: const Text('Spieler entfernen?'),
                      content: Text('${player.name} aus dem Raum entfernen?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Abbrechen'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentRed,
                          ),
                          child: const Text('Entfernen'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) onKick();
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.accentRed.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.remove_circle_outline,
                    color: AppTheme.accentRed,
                    size: 20,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStartButton(BuildContext context, Room room, GameService gameService) {
    final canStart = room.canStart;

    return FadeSlideTransition(
      delay: const Duration(milliseconds: 400),
      child: GradientButton(
        text: 'Spiel starten',
        icon: Icons.play_arrow,
        gradient: canStart
            ? AppTheme.successGradient
            : LinearGradient(
                colors: [Colors.grey.shade600, Colors.grey.shade700],
              ),
        onPressed: canStart ? () => gameService.startGame() : null,
      ),
    );
  }

  Widget _buildWaitingMessage(BuildContext context) {
    return FadeSlideTransition(
      delay: const Duration(milliseconds: 400),
      child: GlassCard(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            PulsingWidget(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.hourglass_empty, color: Colors.white),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Warte auf den Host...',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Das Spiel beginnt sobald der Host startet',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
