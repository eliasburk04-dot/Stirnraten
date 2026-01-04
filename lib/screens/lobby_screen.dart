import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:ui';

import '../services/game_service.dart';
import '../models/models.dart';
import '../utils/theme.dart';
import '../widgets/glass_widgets.dart';
import 'game_screen.dart';
import 'home_screen.dart';
import 'bomb_party_screen.dart';

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
            Widget nextScreen;
            if (room.gameType == GameType.bombParty) {
              nextScreen = const BombPartyScreen();
            } else {
              nextScreen = const GameScreen();
            }

            Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => nextScreen,
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
            body: ModernBackground(
              child: SafeArea(
                child: Column(
                  children: [
                    _buildAppBar(context, gameService),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildRoomCodeCard(context, room.code),
                            const SizedBox(height: 24),
                            _buildPlayersCard(context, room, gameService),
                            const SizedBox(height: 32),
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
      padding: const EdgeInsets.all(24),
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
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
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
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Warteraum',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: 0.2,
                ),
              ),
              Text(
                'Warte auf Mitspieler...',
                style: TextStyle(
                  color: Colors.white.withAlpha(128),
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.2,
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
                    color: Color.fromRGBO(239,68,68,0.2),
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
    return GlassCard(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFA855F7), Color(0xFFEC4899)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.vpn_key, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Raum-Code',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.qr_code_2, color: Colors.white70),
                onPressed: () => _showQRCodeDialog(context, code),
                tooltip: 'QR-Code anzeigen',
              ),
            ],
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check, color: Colors.white, size: 16),
                      ),
                      const SizedBox(width: 12),
                      const Text('Code kopiert!'),
                    ],
                  ),
                  backgroundColor: const Color(0xFF1F1F2E),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  margin: const EdgeInsets.all(16),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(13),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFA855F7).withAlpha(77),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Color(0xFFA855F7), Color(0xFFEC4899)],
                        ).createShader(bounds),
                        child: Text(
                          code,
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 10,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFA855F7).withAlpha(51),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.copy,
                          color: Color(0xFFA855F7),
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayersCard(BuildContext context, Room room, GameService gameService) {
    final isHost = gameService.isHost;

    return GlassCard(
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
                      gradient: const LinearGradient(
                        colors: [Color(0xFF06B6D4), Color(0xFF3B82F6)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.people, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Spieler',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: room.canStart
                      ? const Color(0xFF10B981).withAlpha(51)
                      : const Color(0xFFF59E0B).withAlpha(51),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: room.canStart
                        ? const Color(0xFF10B981).withAlpha(102)
                        : const Color(0xFFF59E0B).withAlpha(102),
                  ),
                ),
                child: Text(
                  '${room.players.length}/${room.maxPlayers}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: room.canStart ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          if (!room.canStart) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withAlpha(26),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFF59E0B).withAlpha(51),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFFF59E0B), size: 18),
                  const SizedBox(width: 10),
                  Text(
                    'Mindestens ${room.minPlayers} Spieler benötigt',
                    style: const TextStyle(
                      color: Color(0xFFF59E0B),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          ...room.players.asMap().entries.map((entry) {
            final player = entry.value;
            return _buildPlayerTile(
              context,
              player,
              isHost && player.id != room.hostId,
              () => gameService.kickPlayer(player.id),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPlayerTile(
    BuildContext context,
    Player player,
    bool canKick,
    VoidCallback onKick,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(13),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(26)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: player.avatarColor,
              borderRadius: BorderRadius.circular(12),
              border: player.isHost
                  ? Border.all(
                      color: Colors.white.withAlpha(102),
                      width: 2,
                    )
                  : null,
            ),
            child: Center(
              child: Text(
                player.name.isNotEmpty ? player.name[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
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
                  player.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
                if (player.isHost)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFA855F7), Color(0xFFEC4899)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'HOST',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
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
                    backgroundColor: const Color(0xFF1F1F2E),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    title: const Text('Spieler entfernen?', style: TextStyle(color: Colors.white)),
                    content: Text(
                      '${player.name} aus dem Raum entfernen?',
                      style: TextStyle(color: Colors.white.withAlpha(179)),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(
                          'Abbrechen',
                          style: TextStyle(color: Colors.white.withAlpha(179)),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                          foregroundColor: Colors.white,
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
                  color: const Color(0xFFEF4444).withAlpha(51),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.remove_circle_outline,
                  color: Color(0xFFEF4444),
                  size: 20,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStartButton(BuildContext context, Room room, GameService gameService) {
    final canStart = room.canStart;

    return GlassButton(
      text: 'Spiel starten',
      isFullWidth: true,
      gradientColors: canStart
          ? const [Color(0xFF10B981), Color(0xFF059669)]
          : const [Color(0xFF4B5563), Color(0xFF374151)],
      onPressed: canStart ? () => gameService.startGame() : null,
    );
  }

  Widget _buildWaitingMessage(BuildContext context) {
    return GlassCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFA855F7), Color(0xFFEC4899)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.hourglass_empty, color: Colors.white),
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
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Das Spiel beginnt sobald der Host startet',
                  style: TextStyle(
                    color: Colors.white.withAlpha(128),
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

  void _showQRCodeDialog(BuildContext context, String code) {
    // Create a simple join link that is easily recognized by QR scanners
    String baseUrl = 'https://luegnerspiel.web.app';
    if (kIsWeb) {
      try {
        baseUrl = Uri.base.origin;
      } catch (e) {
        // Fallback to default URL if Uri.base fails
      }
    }
    final String joinUrl = '$baseUrl/?code=$code';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Beitreten',
              style: TextStyle(
                color: Colors.black,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Scanne diesen Code zum Beitreten',
              style: TextStyle(color: Colors.black.withOpacity(0.6), fontSize: 14),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: QrImageView(
                data: joinUrl,
                version: QrVersions.auto,
                size: 200.0,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              code,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 32,
                fontWeight: FontWeight.w800,
                letterSpacing: 8,
              ),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Schließen',
                style: TextStyle(color: AppTheme.primaryPurple, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
