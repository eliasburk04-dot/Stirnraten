import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/game_service.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../services/sound_service.dart';

class FusePainter extends CustomPainter {
  final double progress; // 0.0 to 1.0
  final bool isExploding;
  final Random random = Random();

  FusePainter({required this.progress, this.isExploding = false});

  @override
  void paint(Canvas canvas, Size size) {
    if (isExploding || progress <= 0) return;

    final fusePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    // 1. Fuse Path
    final path = Path();
    path.moveTo(size.width * 0.2, size.height * 0.8);
    path.quadraticBezierTo(
      size.width * 0.5, 
      size.height * 0.2, 
      size.width * 0.9, 
      size.height * 0.5
    );

    final metrics = path.computeMetrics().first;
    final totalLength = metrics.length;
    final currentLength = totalLength * progress;

    // Draw unburnt fuse (dark/charred look)
    canvas.drawPath(path, fusePaint..color = Colors.black87);

    // Draw burning fuse (glowing core)
    final burntPath = metrics.extractPath(0, currentLength);
    canvas.drawPath(
      burntPath, 
      fusePaint
        ..color = const Color(0xFF5D4037)
        ..strokeWidth = 6
    );

    // 2. The Spark (The "Burning" Point)
    final tangent = metrics.getTangentForOffset(currentLength);
    if (tangent != null) {
      final pos = tangent.position;

      // Core Glow
      canvas.drawCircle(pos, 12, Paint()..color = Colors.orange.withValues(alpha: 0.4)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
      canvas.drawCircle(pos, 6, Paint()..color = Colors.yellow);
      canvas.drawCircle(pos, 3, Paint()..color = Colors.white);

      // Sparks (Particles)
      for (int i = 0; i < 12; i++) {
        final angle = random.nextDouble() * 2 * pi;
        final dist = 5.0 + random.nextDouble() * 25.0;
        final sparkPos = Offset(
          pos.dx + cos(angle) * dist,
          pos.dy + sin(angle) * dist,
        );
        
        canvas.drawCircle(
          sparkPos, 
          random.nextDouble() * 2, 
          Paint()..color = random.nextBool() ? Colors.orange : Colors.yellow
        );
      }

      // Smoke (Subtle grey clouds)
      for (int i = 0; i < 3; i++) {
        final smokeOffset = Offset(
          pos.dx + (random.nextDouble() - 0.5) * 20,
          pos.dy - random.nextDouble() * 40,
        );
        canvas.drawCircle(
          smokeOffset, 
          8 + random.nextDouble() * 12, 
          Paint()..color = Colors.white.withValues(alpha: 0.05)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10)
        );
      }
    }
  }

  @override
  bool shouldRepaint(FusePainter oldDelegate) => true; // Always repaint for spark jitter
}

class BombPartyScreen extends StatefulWidget {
  const BombPartyScreen({super.key});

  @override
  State<BombPartyScreen> createState() => _BombPartyScreenState();
}

class _BombPartyScreenState extends State<BombPartyScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _wordController = TextEditingController();
  late AnimationController _bombController;
  Timer? _localTimer;
  int _localTimerSeconds = 15;
  double _fuseProgress = 1.0;
  bool _isExploding = false;

  @override
  void initState() {
    super.initState();
    _bombController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    // Start local timer sync
    _startLocalTimer();
  }

  void _startLocalTimer() {
    _localTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      final gameService = Provider.of<GameService>(context, listen: false);
      final room = gameService.currentRoom;
      if (room == null || room.state != GameState.playing) return;

      if (room.turnEndsAt != null) {
        final now = DateTime.now().millisecondsSinceEpoch;
        final remainingMs = room.turnEndsAt! - now;
        final remaining = (remainingMs / 1000).ceil();
        
        // Update fuse progress (15 seconds total)
        final newFuseProgress = (remainingMs / 15000).clamp(0.0, 1.0);

        if (remaining != _localTimerSeconds || (newFuseProgress - _fuseProgress).abs() > 0.005) {
          setState(() {
            _localTimerSeconds = remaining.clamp(0, 15);
            _fuseProgress = newFuseProgress;
          });
        }

        if (_localTimerSeconds <= 0 && gameService.isHost && !_isExploding) {
          _handleExplosion();
        }
        
        if (_localTimerSeconds <= 5 && _localTimerSeconds > 0) {
          Provider.of<SoundService>(context, listen: false).playTick();
          _bombController.repeat(reverse: true);
        } else {
          _bombController.stop();
        }
      }
    });
  }

  Future<void> _handleExplosion() async {
    setState(() => _isExploding = true);
    Provider.of<SoundService>(context, listen: false).playExplosion();
    final gameService = Provider.of<GameService>(context, listen: false);
    await gameService.handleExplosion();
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _isExploding = false);
  }

  @override
  void dispose() {
    _localTimer?.cancel();
    _wordController.dispose();
    _bombController.dispose();
    super.dispose();
  }

  void _submitWord() async {
    if (_wordController.text.isEmpty) return;
    
    final gameService = Provider.of<GameService>(context, listen: false);
    final soundService = Provider.of<SoundService>(context, listen: false);
    final success = await gameService.submitBombWord(_wordController.text);
    
    if (success) {
      _wordController.clear();
      soundService.playSuccess();
    } else {
      // Shake animation or error feedback
      soundService.playError();
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameService = Provider.of<GameService>(context);
    final room = gameService.currentRoom;
    final currentPlayer = gameService.currentPlayer;

    if (room == null || currentPlayer == null) return const Scaffold();

    final isActive = room.activePlayerId == currentPlayer.id;
    final activePlayer = room.players.firstWhere((p) => p.id == room.activePlayerId, orElse: () => room.players.first);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context, room),
              Expanded(
                child: room.state == GameState.gameOver 
                  ? _buildGameOver(context, room, gameService)
                  : _buildGameContent(context, room, isActive, activePlayer, gameService),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, dynamic room) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'BOMB PARTY',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              Text(
                'Raum: ${room.code}',
                style: TextStyle(color: Colors.white.withOpacity(0.6)),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.red.withOpacity(0.5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.timer, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Text(
                  '$_localTimerSeconds',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameContent(BuildContext context, dynamic room, bool isActive, Player activePlayer, GameService gameService) {
    return Column(
      children: [
        const SizedBox(height: 40),
        // Bomb and Syllable
        AnimatedBuilder(
          animation: _bombController,
          builder: (context, child) {
            return Transform.rotate(
              angle: _bombController.value * 0.1 * (Random().nextBool() ? 1 : -1),
              child: child,
            );
          },
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Fuse
              Positioned(
                top: -80,
                right: -60,
                child: CustomPaint(
                  size: const Size(150, 150),
                  painter: FusePainter(
                    progress: _fuseProgress,
                    isExploding: _isExploding,
                  ),
                ),
              ),
              // Wick Base
              Positioned(
                top: 0,
                child: Container(
                  width: 40,
                  height: 25,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C2C2C),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.black, width: 1),
                  ),
                ),
              ),
              // Bomb Body (Using the realistic image)
              AnimatedBuilder(
                animation: _bombController,
                builder: (context, child) {
                  double scale = 1.0;
                  if (_isExploding) {
                    scale = 1.0 + (_bombController.value * 2.0);
                  } else if (_localTimerSeconds <= 5) {
                    scale = 1.0 + (sin(_bombController.value * pi) * 0.05);
                  }
                  
                  return Transform.scale(
                    scale: scale,
                    child: Opacity(
                      opacity: _isExploding ? (1.0 - _bombController.value).clamp(0.0, 1.0) : 1.0,
                      child: child,
                    ),
                  );
                },
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.6),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                      BoxShadow(
                        color: Colors.orange.withValues(alpha: _localTimerSeconds <= 5 || _isExploding ? 0.4 : 0.0),
                        blurRadius: 40,
                        spreadRadius: _isExploding ? _bombController.value * 100 : 10,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(110),
                    child: Image.asset(
                      'assets/images/bomb.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.black,
                          child: const Icon(Icons.error, color: Colors.orange, size: 50),
                        );
                      },
                    ),
                  ),
                ),
              ),
              if (_isExploding)
                AnimatedBuilder(
                  animation: _bombController,
                  builder: (context, child) {
                    return Container(
                      width: 400 * _bombController.value,
                      height: 400 * _bombController.value,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.white,
                            Colors.yellow.withValues(alpha: 0.8),
                            Colors.orange.withValues(alpha: 0.5),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.2, 0.5, 1.0],
                        ),
                      ),
                    );
                  },
                )
              else
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      room.currentSyllable ?? '...',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Text(
                      'ENTHÄLT',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 40),
        Text(
          isActive ? 'DEIN ZUG!' : '${activePlayer.name} ist dran...',
          style: TextStyle(
            color: isActive ? Colors.orange : Colors.white70,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (room.usedWords.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Letztes Wort: ${room.usedWords.last}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        if (isActive && !_isExploding)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: TextField(
              controller: _wordController,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 24),
              textAlign: TextAlign.center,
              onChanged: (value) {
                gameService.updateBombInput(value);
              },
              decoration: InputDecoration(
                hintText: 'Wort eingeben...',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.orange),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.orange, width: 2),
                ),
              ),
              onSubmitted: (_) => _submitWord(),
            ),
          )
        else if (!isActive && !_isExploding)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              children: [
                Text(
                  room.currentInput ?? '',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                if ((room.currentInput ?? '').isNotEmpty)
                  Container(
                    height: 2,
                    width: 100,
                    margin: const EdgeInsets.only(top: 4),
                    color: Colors.orange.withValues(alpha: 0.5),
                  ),
              ],
            ),
          ),
        const Spacer(),
        _buildPlayersList(room),
      ],
    );
  }

  Widget _buildPlayersList(dynamic room) {
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: room.players.length,
        itemBuilder: (context, index) {
          final player = room.players[index];
          final lives = room.lives[player.id] ?? 0;
          final isActive = room.activePlayerId == player.id;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 90,
            margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: isActive ? Colors.orange.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isActive ? Colors.orange : Colors.white.withValues(alpha: 0.1),
                width: isActive ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Color(int.parse(player.avatarColor.replaceFirst('#', '0xFF'))),
                  child: Text(
                    player.name[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  player.name,
                  style: TextStyle(
                    color: isActive ? Colors.white : Colors.white70,
                    fontSize: 11,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (i) => Icon(
                    Icons.favorite,
                    size: 10,
                    color: i < lives ? Colors.red : Colors.white.withValues(alpha: 0.1),
                  )),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildGameOver(BuildContext context, dynamic room, GameService gameService) {
    final winner = room.players.firstWhere(
      (p) => (room.lives[p.id] ?? 0) > 0,
      orElse: () => room.players.first,
    );

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.emoji_events, size: 100, color: Colors.amber),
          const SizedBox(height: 20),
          const Text(
            'SPIEL VORBEI',
            style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            '${winner.name} hat gewonnen!',
            style: const TextStyle(color: Colors.amber, fontSize: 24),
          ),
          const SizedBox(height: 40),
          if (gameService.isHost)
            ElevatedButton(
              onPressed: () => gameService.playAgain(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              ),
              child: const Text('Nochmal spielen'),
            ),
          TextButton(
            onPressed: () => gameService.endGame(),
            child: const Text('Beenden', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }
}
