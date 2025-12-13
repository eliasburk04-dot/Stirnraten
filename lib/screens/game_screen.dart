import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/game_service.dart';
import '../models/models.dart';
import '../utils/theme.dart';
import '../widgets/animated_widgets.dart';
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
                ? LinearGradient(colors: [color!, color!.withOpacity(0.7)])
                : AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: (color ?? AppTheme.primaryPurple).withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(icon, size: 32, color: Colors.white),
        ),
        const SizedBox(height: 16),
        GradientText(
          text: title,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _QuestioningPhase extends StatelessWidget {
  final Room room;
  final GameService gameService;

  const _QuestioningPhase({required this.room, required this.gameService});

  @override
  Widget build(BuildContext context) {
    final question = gameService.myQuestion;
    final isLiar = gameService.isLiar;
    final isHost = gameService.isHost;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          FadeSlideTransition(
            child: _PhaseHeader(
              title: 'Runde ${room.roundNumber}',
              subtitle: 'Lies deine Frage aufmerksam!',
              icon: Icons.quiz,
            ),
          ),
          const Spacer(),
          if (isLiar)
            FadeSlideTransition(
              delay: const Duration(milliseconds: 200),
              child: PulsingWidget(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: AppTheme.liarGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accentRed.withOpacity(0.4),
                        blurRadius: 15,
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning_amber, color: Colors.white, size: 22),
                      SizedBox(width: 10),
                      Text(
                        'Du bist der LÜGNER! Pass dich an!',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 24),
          FadeSlideTransition(
            delay: const Duration(milliseconds: 300),
            child: AnimatedGradientBorder(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryPurple.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.help_outline, size: 36, color: AppTheme.primaryPurple),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      question?.question ?? 'Lade Frage...',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Spacer(),
          FadeSlideTransition(
            delay: const Duration(milliseconds: 400),
            child: isHost
                ? GradientButton(
                    text: 'Antworten starten',
                    icon: Icons.arrow_forward,
                    onPressed: () => gameService.startAnswering(),
                  )
                : Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryPurple),
                        ),
                        const SizedBox(width: 12),
                        Text('Warte auf den Host...', style: TextStyle(color: Colors.white.withOpacity(0.6))),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
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
          FadeSlideTransition(
            child: _PhaseHeader(
              title: 'Antworten',
              subtitle: 'Gib deine Antwort ein',
              icon: Icons.edit_note,
            ),
          ),
          const SizedBox(height: 20),
          AnimatedCounter(value: answeredCount, total: totalPlayers, label: 'haben geantwortet'),
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
                    style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.8)),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          _hasSubmitted
              ? FadeSlideTransition(
                  child: GlassCard(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.accentGreen.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check_circle, color: AppTheme.accentGreen, size: 48),
                        ),
                        const SizedBox(height: 16),
                        const Text('Antwort abgeschickt!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.accentGreen)),
                        const SizedBox(height: 8),
                        Text('Warte auf andere Spieler...', style: TextStyle(color: Colors.white.withOpacity(0.6))),
                      ],
                    ),
                  ),
                )
              : FadeSlideTransition(
                  child: GlassCard(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        TextField(
                          controller: _answerController,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 20),
                          decoration: InputDecoration(
                            hintText: 'Deine Antwort',
                            hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                          ),
                          onSubmitted: (_) => _submitAnswer(),
                        ),
                        const SizedBox(height: 20),
                        GradientButton(
                          text: 'Antwort abschicken',
                          icon: Icons.send,
                          onPressed: _submitAnswer,
                        ),
                      ],
                    ),
                  ),
                ),
          const Spacer(),
          _buildAnsweredList(),
        ],
      ),
    );
  }

  Widget _buildAnsweredList() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: widget.room.players.map((player) {
        final hasAnswered = player.hasAnswered;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: hasAnswered ? AppTheme.accentGreen.withOpacity(0.2) : Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: hasAnswered ? AppTheme.accentGreen : Colors.white.withOpacity(0.2)),
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
          PulsingWidget(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(gradient: AppTheme.primaryGradient, shape: BoxShape.circle),
              child: const Icon(Icons.hourglass_empty, size: 48, color: Colors.white),
            ),
          ),
          const SizedBox(height: 24),
          const Text('Warte auf alle Spieler...', style: TextStyle(fontSize: 18)),
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
          FadeSlideTransition(
            child: _PhaseHeader(
              title: 'Abstimmung!',
              subtitle: 'Wer hatte eine andere Frage?',
              icon: Icons.how_to_vote,
              color: AppTheme.accentRed,
            ),
          ),
          const SizedBox(height: 16),
          AnimatedCounter(value: votedCount, total: totalPlayers, label: 'haben gewählt', color: AppTheme.accentRed),
          const SizedBox(height: 16),
          GlassCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Die Frage war:', style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.5))),
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
                    color: AppTheme.accentGreen.withOpacity(0.2),
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
              : GradientButton(
                  text: 'Stimme abgeben',
                  icon: Icons.how_to_vote,
                  gradient: AppTheme.liarGradient,
                  onPressed: _selectedPlayerId != null ? _submitVote : null,
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
          color: isSelected ? AppTheme.accentRed.withOpacity(0.3) : isMe ? AppTheme.primaryPurple.withOpacity(0.1) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? AppTheme.accentRed : isMe ? AppTheme.primaryPurple.withOpacity(0.3) : Colors.transparent, width: 2),
        ),
        child: Row(
          children: [
            PlayerAvatar(name: player.name, color: player.avatarColor, size: 40),
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
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(player.answer ?? '', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
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
          FadeSlideTransition(
            child: _PhaseHeader(
              title: 'Ergebnisse',
              subtitle: 'Die Stimmen sind gezählt!',
              icon: Icons.bar_chart,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.builder(
              itemCount: room.players.length,
              itemBuilder: (context, index) {
                final player = room.players[index];
                final votes = room.getVotesFor(player.id);
                return FadeSlideTransition(
                  delay: Duration(milliseconds: 100 * index),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        PlayerAvatar(name: player.name, color: player.avatarColor, size: 44),
                        const SizedBox(width: 14),
                        Expanded(child: Text(player.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: votes > 0 ? AppTheme.accentRed.withOpacity(0.2) : Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$votes ${votes == 1 ? "Stimme" : "Stimmen"}',
                            style: TextStyle(fontWeight: FontWeight.bold, color: votes > 0 ? AppTheme.accentRed : Colors.white54),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (gameService.isHost)
            GradientButton(
              text: 'Lügner enthüllen',
              icon: Icons.visibility,
              gradient: AppTheme.liarGradient,
              onPressed: () => gameService.revealLiar(),
            ),
        ],
      ),
    );
  }
}

class _RevealPhase extends StatelessWidget {
  final Room room;
  final GameService gameService;

  const _RevealPhase({required this.room, required this.gameService});

  @override
  Widget build(BuildContext context) {
    final liar = room.players.where((p) => p.id == room.liarId).firstOrNull;
    final liarWasCaught = room.liarWasCaught;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          FadeSlideTransition(
            child: _PhaseHeader(
              title: liarWasCaught ? 'Erwischt!' : 'Entkommen!',
              subtitle: liarWasCaught ? 'Der Lügner wurde gefunden!' : 'Der Lügner ist entkommen!',
              icon: liarWasCaught ? Icons.celebration : Icons.sentiment_very_dissatisfied,
              color: liarWasCaught ? AppTheme.accentGreen : AppTheme.accentRed,
            ),
          ),
          const Spacer(),
          if (liar != null)
            FadeSlideTransition(
              delay: const Duration(milliseconds: 300),
              child: Column(
                children: [
                  PulsingWidget(
                    child: PlayerAvatar(name: liar.name, color: liar.avatarColor, size: 100, isLiar: true, showBorder: true),
                  ),
                  const SizedBox(height: 20),
                  const Text('Der Lügner war:', style: TextStyle(color: Colors.white54)),
                  const SizedBox(height: 8),
                  GradientText(
                    text: liar.name,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                    gradient: AppTheme.liarGradient,
                  ),
                  const SizedBox(height: 24),
                  GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text('Die Lügner-Frage:', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5))),
                        const SizedBox(height: 8),
                        Text(room.liarQuestion?.question ?? '', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const Spacer(),
          if (gameService.isHost) ...[
            GradientButton(
              text: 'Nochmal spielen',
              icon: Icons.replay,
              onPressed: () => gameService.playAgain(),
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
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: Center(child: Text('Beenden', style: TextStyle(color: Colors.white.withOpacity(0.7)))),
              ),
            ),
          ] else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(14)),
              child: const Text('Warte auf den Host...'),
            ),
        ],
      ),
    );
  }
}
