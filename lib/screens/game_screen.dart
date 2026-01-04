import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/game_service.dart';
import '../services/sound_service.dart';
import '../models/models.dart';
import '../utils/theme.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/common_widgets.dart';
import 'home_screen.dart';
import 'lobby_screen.dart';

class GameScreen extends StatelessWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<GameService>(
      builder: (context, gameService, child) {
        final room = gameService.currentRoom;

        if (room == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomeScreen()),
            );
          });
          return Scaffold(
            body: Container(
              decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
              child: const Center(child: CircularProgressIndicator(color: AppTheme.primaryPurple)),
            ),
          );
        }

        // Wenn wir wieder in der Lobby sind (z.B. nach "Nochmal spielen"), zurück zum LobbyScreen
        if (room.state == GameState.lobby) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const LobbyScreen()),
            );
          });
          return Scaffold(
            body: Container(
              decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
              child: const Center(child: CircularProgressIndicator(color: AppTheme.primaryPurple)),
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
                child: _buildGamePhase(context, room, gameService),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<bool> _showLeaveDialog(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppTheme.cardDark,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Spiel verlassen?'),
            content: const Text('Bist du sicher, dass du das Spiel verlassen möchtest?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Abbrechen'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentRed),
                child: const Text('Verlassen'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Widget _buildGamePhase(BuildContext context, Room room, GameService gameService) {
    switch (room.state) {
      case GameState.questioning:
        return _QuestioningPhase(room: room, gameService: gameService);
      case GameState.answering:
        return _AnsweringPhase(room: room, gameService: gameService);
      case GameState.waiting:
        return _WaitingPhase(room: room, gameService: gameService);
      case GameState.voting:
        return _VotingPhase(room: room, gameService: gameService);
      case GameState.results:
        return _ResultsPhase(room: room, gameService: gameService);
      case GameState.reveal:
        return _RevealPhase(room: room, gameService: gameService);
      case GameState.playing:
      case GameState.gameOver:
        return const Center(child: Text('Game in progress...'));
      case GameState.lobby:
        return const Center(child: CircularProgressIndicator());
    }
  }
}

class _PhaseHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color? color;

  const _PhaseHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: color != null
                ? LinearGradient(colors: [color!, color!])
                : const LinearGradient(colors: [Color(0xFFA855F7), Color(0xFFEC4899)]),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(icon, size: 32, color: Colors.white),
        ),
        const SizedBox(height: 16),
        ShaderMask(
          shaderCallback: (bounds) => (color != null
              ? LinearGradient(colors: [color!, color!])
              : const LinearGradient(colors: [Color(0xFFA855F7), Color(0xFFEC4899)])
          ).createShader(bounds),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(
            color: Colors.white.withAlpha(140),
            fontSize: 14,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.2,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _QuestioningPhase extends StatefulWidget {
  final Room room;
  final GameService gameService;

  const _QuestioningPhase({required this.room, required this.gameService});

  @override
  State<_QuestioningPhase> createState() => _QuestioningPhaseState();
}

class _QuestioningPhaseState extends State<_QuestioningPhase> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<SoundService>().playStart();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    final gameService = widget.gameService;
    final question = gameService.myQuestion;
    final isHost = gameService.isHost;
    final player = gameService.currentPlayer;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _PhaseHeader(
            title: 'Runde ${room.roundNumber}',
            subtitle: 'Lies deine Frage aufmerksam!',
            icon: Icons.quiz,
          ),
          const SizedBox(height: 20),
          if (player != null && player.role != PlayerRole.normal)
            _buildRoleInfo(player, room),
          const Spacer(),
          const SizedBox(height: 24),
          GlassCard(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFA855F7), Color(0xFFEC4899)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.help_outline, size: 36, color: Colors.white),
                ),
                const SizedBox(height: 24),
                Text(
                  question?.question ?? 'Lade Frage...',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    height: 1.4,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          isHost
              ? GlassButton(
                  text: 'Antworten starten',
                  isFullWidth: true,
                  gradientColors: const [Color(0xFFA855F7), Color(0xFFEC4899)],
                  onPressed: () => gameService.startAnswering(),
                )
              : GlassCard(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryPurple),
                        ),
                        const SizedBox(width: 12),
                        Text('Warte auf den Host...', style: TextStyle(color: Color.fromRGBO(255,255,255,0.6))),
                      ],
                    ),
                  ),
        ],
      ),
    );
  }

  Widget _buildRoleInfo(Player player, Room room) {
    if (player.role == PlayerRole.detective) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.withOpacity(0.3)),
        ),
        child: const Row(
          children: [
            Text('🕵️', style: TextStyle(fontSize: 20)),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Detektiv-Hinweis', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 13)),
                  Text('Du spürst, dass die Fragen in dieser Runde unterschiedlich sind!', style: TextStyle(color: Colors.white70, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      );
    } else if (player.role == PlayerRole.accomplice) {
      final otherLiars = room.liars.where((p) => p.id != player.id).map((p) => p.name).join(', ');
      if (otherLiars.isEmpty) return const SizedBox.shrink();
      
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Text('🤝', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Komplizen-Info', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
                  Text('Deine Mit-Lügner: $otherLiars', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

class _AnsweringPhase extends StatefulWidget {
  final Room room;
  final GameService gameService;

  const _AnsweringPhase({required this.room, required this.gameService});

  @override
  State<_AnsweringPhase> createState() => _AnsweringPhaseState();
}

class _AnsweringPhaseState extends State<_AnsweringPhase> {
  final _answerController = TextEditingController();
  bool _hasSubmitted = false;

  @override
  void initState() {
    super.initState();
    _hasSubmitted = widget.gameService.currentPlayer?.hasAnswered ?? false;
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  void _submitAnswer() async {
    final answer = _answerController.text.trim();
    if (answer.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte gib eine Antwort ein')),
      );
      return;
    }
    context.read<SoundService>().playClick();
    await widget.gameService.submitAnswer(answer);
    setState(() => _hasSubmitted = true);
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.gameService.myQuestion;
    final answeredCount = widget.room.playersWhoAnswered.length;
    final totalPlayers = widget.room.players.length;

    if (widget.room.allAnswered && widget.gameService.isHost) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.gameService.startVoting();
      });
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const _PhaseHeader(
            title: 'Antworten',
            subtitle: 'Gib deine Antwort ein',
            icon: Icons.edit_note,
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: answeredCount == totalPlayers
                  ? const Color(0xFF10B981).withAlpha(51)
                  : const Color(0xFFF59E0B).withAlpha(51),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: answeredCount == totalPlayers
                    ? const Color(0xFF10B981).withAlpha(102)
                    : const Color(0xFFF59E0B).withAlpha(102),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  answeredCount == totalPlayers
                      ? Icons.check_circle
                      : Icons.hourglass_empty,
                  color: answeredCount == totalPlayers
                      ? const Color(0xFF10B981)
                      : const Color(0xFFF59E0B),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  '$answeredCount/$totalPlayers geantwortet',
                  style: TextStyle(
                    color: answeredCount == totalPlayers
                        ? const Color(0xFF10B981)
                        : const Color(0xFFF59E0B),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.quiz, color: AppTheme.primaryPurple, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    question?.question ?? '',
                    style: TextStyle(fontSize: 13, color: Color.fromRGBO(255,255,255,0.8)),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          _hasSubmitted
              ? GlassCard(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Color.fromRGBO(16,185,129,0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_circle, color: AppTheme.accentGreen, size: 48),
                      ),
                      const SizedBox(height: 16),
                      const Text('Antwort abgeschickt!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.accentGreen)),
                      const SizedBox(height: 8),
                      Text('Warte auf andere Spieler...', style: TextStyle(color: Color.fromRGBO(255,255,255,0.6))),
                    ],
                  ),
                )
              : GlassCard(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        TextField(
                          controller: _answerController,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 20),
                          decoration: InputDecoration(
                            hintText: 'Deine Antwort',
                            hintStyle: TextStyle(color: Color.fromRGBO(255,255,255,0.3)),
                          ),
                          onSubmitted: (_) => _submitAnswer(),
                        ),
                        const SizedBox(height: 20),
                        GlassButton(
                          text: 'Antwort abschicken',
                          icon: Icons.send,
                          onPressed: _submitAnswer,
                          isFullWidth: true,
                          gradientColors: const [Color(0xFFA855F7), Color(0xFFEC4899)],
                        ),
                      ],
                    ),
                  ),
          const Spacer(),
          _buildAnsweredList(),
        ],
      ),
    );
  }

  Widget _buildAnsweredList() {
    return Column(
      children: [
        Text(
          'Wer hat schon geantwortet?',
          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: widget.room.players.map((player) {
            final hasAnswered = player.hasAnswered;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: hasAnswered ? Color.fromRGBO(16,185,129,0.2) : Color.fromRGBO(255,255,255,0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: hasAnswered ? AppTheme.accentGreen : Color.fromRGBO(255,255,255,0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(hasAnswered ? Icons.check : Icons.hourglass_empty, size: 14, color: hasAnswered ? AppTheme.accentGreen : Colors.white54),
                  const SizedBox(width: 6),
                  Text(player.name, style: TextStyle(fontSize: 12, color: hasAnswered ? AppTheme.accentGreen : Colors.white54)),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _WaitingPhase extends StatelessWidget {
  final Room room;
  final GameService gameService;

  const _WaitingPhase({required this.room, required this.gameService});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GlassCard(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryPurple),
                ),
                const SizedBox(width: 16),
                Text('Warte auf alle Spieler...', style: TextStyle(color: Color.fromRGBO(255,255,255,0.8), fontSize: 16)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VotingPhase extends StatefulWidget {
  final Room room;
  final GameService gameService;

  const _VotingPhase({required this.room, required this.gameService});

  @override
  State<_VotingPhase> createState() => _VotingPhaseState();
}

class _VotingPhaseState extends State<_VotingPhase> {
  String? _selectedPlayerId;
  bool _hasVoted = false;

  @override
  void initState() {
    super.initState();
    _hasVoted = widget.gameService.currentPlayer?.hasVoted ?? false;
  }

  void _submitVote() async {
    if (_selectedPlayerId == null) return;
    context.read<SoundService>().playClick();
    await widget.gameService.submitVote(_selectedPlayerId!);
    setState(() => _hasVoted = true);
  }

  @override
  Widget build(BuildContext context) {
    final currentQuestion = widget.room.currentQuestion;
    final votedCount = widget.room.playersWhoVoted.length;
    final totalPlayers = widget.room.players.length;

    if (widget.room.allVoted && widget.gameService.isHost) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.gameService.showResults();
      });
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const _PhaseHeader(
            title: 'Abstimmung!',
            subtitle: 'Wer hatte eine andere Frage?',
            icon: Icons.how_to_vote,
            color: AppTheme.accentRed,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.accentRed.withAlpha(51),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.accentRed.withAlpha(102)),
            ),
            child: Text(
              '$votedCount/$totalPlayers haben gewählt',
              style: const TextStyle(
                color: AppTheme.accentRed,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 16),
          GlassCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Die Frage war:', style: TextStyle(fontSize: 11, color: Color.fromRGBO(255,255,255,0.5))),
                const SizedBox(height: 6),
                Text(currentQuestion?.question ?? '', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: widget.room.players.length,
              itemBuilder: (context, index) {
                final player = widget.room.players[index];
                return _buildAnswerTile(player);
              },
            ),
          ),
          const SizedBox(height: 16),
          _hasVoted
              ? Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Color.fromRGBO(16,185,129,0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: AppTheme.accentGreen),
                      SizedBox(width: 10),
                      Text('Stimme abgegeben! Warte...', style: TextStyle(color: AppTheme.accentGreen)),
                    ],
                  ),
                )
              : GlassButton(
                  text: 'Stimme abgeben',
                  icon: Icons.how_to_vote,
                  gradientColors: const [Color(0xFFEF4444), Color(0xFFF59E0B)],
                  onPressed: _selectedPlayerId != null ? _submitVote : null,
                  isFullWidth: true,
                ),
        ],
      ),
    );
  }

  Widget _buildAnswerTile(Player player) {
    final isMe = player.id == widget.gameService.currentPlayer?.id;
    final isSelected = player.id == _selectedPlayerId;

    return GestureDetector(
      onTap: _hasVoted || isMe ? null : () => setState(() => _selectedPlayerId = player.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? Color.fromRGBO(239,68,68,0.3) : isMe ? Color.fromRGBO(124,58,237,0.1) : Color.fromRGBO(255,255,255,0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? AppTheme.accentRed : isMe ? Color.fromRGBO(124,58,237,0.3) : Colors.transparent, width: 2),
        ),
        child: Row(
          children: [
            PlayerAvatar(player: player, radius: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(player.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      if (isMe) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: AppTheme.primaryPurple, borderRadius: BorderRadius.circular(8)),
                          child: const Text('DU', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                      if (player.hasVoted) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.check_circle, color: AppTheme.accentGreen, size: 14),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(player.answer ?? '', style: TextStyle(color: Color.fromRGBO(255,255,255,0.7), fontSize: 13)),
                ],
              ),
            ),
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(color: AppTheme.accentRed, shape: BoxShape.circle),
                child: const Icon(Icons.check, color: Colors.white, size: 16),
              ),
          ],
        ),
      ),
    );
  }
}

class _ResultsPhase extends StatelessWidget {
  final Room room;
  final GameService gameService;

  const _ResultsPhase({required this.room, required this.gameService});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const _PhaseHeader(
            title: 'Ergebnisse',
            subtitle: 'Die Stimmen sind gezählt!',
            icon: Icons.bar_chart,
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.builder(
              itemCount: room.players.length,
              itemBuilder: (context, index) {
                final player = room.players[index];
                final votes = room.getVotesFor(player.id);
                return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Color.fromRGBO(255,255,255,0.05),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        PlayerAvatar(player: player, radius: 22),
                        const SizedBox(width: 14),
                        Expanded(child: Text(player.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: votes > 0 ? Color.fromRGBO(239,68,68,0.2) : Color.fromRGBO(255,255,255,0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$votes ${votes == 1 ? "Stimme" : "Stimmen"}',
                            style: TextStyle(fontWeight: FontWeight.bold, color: votes > 0 ? AppTheme.accentRed : Colors.white54),
                          ),
                        ),
                      ],
                    ),
                  );
              },
            ),
          ),
          if (gameService.isHost)
            GlassButton(
              text: 'Lügner enthüllen',
              icon: Icons.visibility,
              gradientColors: const [Color(0xFFEF4444), Color(0xFFF59E0B)],
              onPressed: () => gameService.revealLiar(),
              isFullWidth: true,
            ),
        ],
      ),
    );
  }
}

class _RevealPhase extends StatefulWidget {
  final Room room;
  final GameService gameService;

  const _RevealPhase({required this.room, required this.gameService});

  @override
  State<_RevealPhase> createState() => _RevealPhaseState();
}

class _RevealPhaseState extends State<_RevealPhase> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<SoundService>().playEnd();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    final gameService = widget.gameService;
    final liars = room.liars;
    final liarWasCaught = room.liarWasCaught;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _PhaseHeader(
            title: liarWasCaught ? 'Erwischt!' : 'Entkommen!',
            subtitle: liarWasCaught 
                ? (liars.length > 1 ? 'Ein Lügner wurde gefunden!' : 'Der Lügner wurde gefunden!')
                : (liars.length > 1 ? 'Die Lügner sind entkommen!' : 'Der Lügner ist entkommen!'),
            icon: liarWasCaught ? Icons.celebration : Icons.sentiment_very_dissatisfied,
            color: liarWasCaught ? AppTheme.accentGreen : AppTheme.accentRed,
          ),
          const Spacer(),
          if (liars.isNotEmpty)
            Column(
              children: [
                Wrap(
                  spacing: 20,
                  runSpacing: 20,
                  alignment: WrapAlignment.center,
                  children: liars.map((liar) => Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.accentRed, width: 4),
                        ),
                        child: PlayerAvatar(player: liar, radius: 40),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        liar.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  )).toList(),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Die Lügner waren:',
                  style: TextStyle(color: Colors.white54, fontSize: 14),
                ),
                const SizedBox(height: 24),
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text(
                        'Die Lügner-Frage:',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color.fromRGBO(255, 255, 255, 0.5),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        room.liarQuestion?.question ?? '',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          const Spacer(),
          if (gameService.isHost) ...[
            GlassButton(
              text: 'Nochmal spielen',
              icon: Icons.replay,
              onPressed: () => gameService.playAgain(),
              isFullWidth: true,
              gradientColors: const [Color(0xFFA855F7), Color(0xFFEC4899)],
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () async {
                await gameService.endGame();
                if (context.mounted) {
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomeScreen()));
                }
              },
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Color.fromRGBO(255,255,255,0.3)),
                ),
                child: Center(child: Text('Beenden', style: TextStyle(color: Color.fromRGBO(255,255,255,0.7)))),
              ),
            ),
          ] else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Color.fromRGBO(255,255,255,0.05), borderRadius: BorderRadius.circular(14)),
              child: const Text('Warte auf den Host...'),
            ),
        ],
      ),
    );
  }
}
