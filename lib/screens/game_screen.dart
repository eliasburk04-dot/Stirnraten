import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/game_service.dart';
import '../models/models.dart';
import 'home_screen.dart';

class GameScreen extends StatelessWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<GameService>(
      builder: (context, gameService, child) {
        final room = gameService.currentRoom;

        if (room == null) {
          // Room was deleted or player was kicked
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomeScreen()),
            );
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
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
            title: const Text('Leave Game?'),
            content: const Text('Are you sure you want to leave the game?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Leave'),
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
        // Should not happen, but handle gracefully
        return const Center(child: CircularProgressIndicator());
    }
  }
}

// ============================================================================
// QUESTIONING PHASE - Display the question
// ============================================================================

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
          // Header
          _PhaseHeader(
            title: 'Round ${room.roundNumber}',
            subtitle: 'Read your question carefully!',
            icon: Icons.quiz,
          ),
          
          const Spacer(),

          // Secret liar indicator (only visible to liar)
          if (isLiar)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.3),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.red),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning, color: Colors.red, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'You are the LIAR! Blend in!',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),

          // Question Card
          Card(
            elevation: 12,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    Icons.help_outline,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    question?.question ?? 'Loading question...',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ),
            ),
          ),

          const Spacer(),

          // Continue button (host only)
          if (isHost)
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () => gameService.startAnswering(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.arrow_forward),
                label: const Text(
                  'Start Answering',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            )
          else
            const Text(
              'Waiting for host to continue...',
              style: TextStyle(color: Colors.white54),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// ANSWERING PHASE - Submit answer
// ============================================================================

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
        const SnackBar(content: Text('Please enter an answer')),
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

    // Check if all players answered - host moves to voting
    if (widget.room.allAnswered && widget.gameService.isHost) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.gameService.startVoting();
      });
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _PhaseHeader(
            title: 'Answer Time',
            subtitle: 'Enter your answer below',
            icon: Icons.edit,
          ),
          const SizedBox(height: 16),

          // Progress indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$answeredCount / $totalPlayers answered',
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          const SizedBox(height: 24),

          // Question reminder
          Card(
            color: Theme.of(context).colorScheme.surface.withOpacity(0.5),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.quiz,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      question?.question ?? '',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const Spacer(),

          if (_hasSubmitted)
            // Already submitted
            Card(
              color: Colors.green.withOpacity(0.2),
              child: const Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 48),
                    SizedBox(height: 16),
                    Text(
                      'Answer Submitted!',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Waiting for other players...',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            )
          else
            // Answer input
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    TextField(
                      controller: _answerController,
                      keyboardType: TextInputType.text,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 24),
                      decoration: InputDecoration(
                        hintText: 'Your answer',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                      ),
                      onSubmitted: (_) => _submitAnswer(),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _submitAnswer,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text(
                          'Submit Answer',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const Spacer(),

          // Answered players
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
            color: hasAnswered
                ? Colors.green.withOpacity(0.2)
                : Colors.grey.withOpacity(0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasAnswered ? Colors.green : Colors.grey,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                hasAnswered ? Icons.check : Icons.hourglass_empty,
                size: 16,
                color: hasAnswered ? Colors.green : Colors.grey,
              ),
              const SizedBox(width: 4),
              Text(
                player.name,
                style: TextStyle(
                  color: hasAnswered ? Colors.green : Colors.grey,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ============================================================================
// WAITING PHASE - Waiting for all answers
// ============================================================================

class _WaitingPhase extends StatelessWidget {
  final Room room;
  final GameService gameService;

  const _WaitingPhase({required this.room, required this.gameService});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 24),
          Text('Waiting for all players...'),
        ],
      ),
    );
  }
}

// ============================================================================
// VOTING PHASE - Vote for the liar
// ============================================================================

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
    if (_selectedPlayerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a player')),
      );
      return;
    }

    await widget.gameService.submitVote(_selectedPlayerId!);
    setState(() => _hasVoted = true);
  }

  @override
  Widget build(BuildContext context) {
    final currentQuestion = widget.room.currentQuestion;
    final votedCount = widget.room.playersWhoVoted.length;
    final totalPlayers = widget.room.players.length;

    // Check if all players voted - move to results
    if (widget.room.allVoted && widget.gameService.isHost) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.gameService.showResults();
      });
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _PhaseHeader(
            title: 'Vote!',
            subtitle: 'Who had a different question?',
            icon: Icons.how_to_vote,
          ),
          const SizedBox(height: 16),

          // Progress
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$votedCount / $totalPlayers voted',
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          const SizedBox(height: 16),

          // Original question
          Card(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'The Question Was:',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    currentQuestion?.question ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Answers list
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Answers:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.builder(
                        itemCount: widget.room.players.length,
                        itemBuilder: (context, index) {
                          final player = widget.room.players[index];
                          return _buildAnswerTile(player);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          if (_hasVoted)
            Card(
              color: Colors.green.withOpacity(0.2),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 8),
                    Text(
                      'Vote submitted! Waiting for others...',
                      style: TextStyle(color: Colors.green),
                    ),
                  ],
                ),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _selectedPlayerId != null ? _submitVote : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.how_to_vote),
                label: const Text(
                  'Submit Vote',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAnswerTile(Player player) {
    final isMe = player.id == widget.gameService.currentPlayer?.id;
    final isSelected = player.id == _selectedPlayerId;

    return GestureDetector(
      onTap: _hasVoted || isMe
          ? null
          : () => setState(() => _selectedPlayerId = player.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.red.withOpacity(0.3)
              : isMe
                  ? Colors.blue.withOpacity(0.1)
                  : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Colors.red
                : isMe
                    ? Colors.blue.withOpacity(0.3)
                    : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: player.avatarColor,
              radius: 18,
              child: Text(
                player.initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        player.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: isMe ? Colors.blue : null,
                        ),
                      ),
                      if (isMe)
                        const Text(
                          ' (You)',
                          style: TextStyle(color: Colors.blue, fontSize: 12),
                        ),
                    ],
                  ),
                  Text(
                    player.answer ?? 'No answer',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            if (!isMe && !_hasVoted)
              Radio<String>(
                value: player.id,
                groupValue: _selectedPlayerId,
                onChanged: (value) => setState(() => _selectedPlayerId = value),
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// RESULTS PHASE - Show voting results
// ============================================================================

class _ResultsPhase extends StatelessWidget {
  final Room room;
  final GameService gameService;

  const _ResultsPhase({required this.room, required this.gameService});

  @override
  Widget build(BuildContext context) {
    final voteCounts = room.voteCounts;
    final sortedPlayers = List<Player>.from(room.players)
      ..sort((a, b) => (voteCounts[b.id] ?? 0).compareTo(voteCounts[a.id] ?? 0));

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _PhaseHeader(
            title: 'Voting Results',
            subtitle: 'Who received the most votes?',
            icon: Icons.bar_chart,
          ),
          const SizedBox(height: 24),

          Expanded(
            child: ListView.builder(
              itemCount: sortedPlayers.length,
              itemBuilder: (context, index) {
                final player = sortedPlayers[index];
                final votes = voteCounts[player.id] ?? 0;
                final maxVotes = voteCounts.values.reduce((a, b) => a > b ? a : b);

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: votes == maxVotes && maxVotes > 0
                        ? Border.all(color: Colors.red, width: 2)
                        : null,
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: player.avatarColor,
                        child: Text(
                          player.initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          player.name,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: votes == maxVotes && maxVotes > 0
                              ? Colors.red.withOpacity(0.3)
                              : Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$votes votes',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: votes == maxVotes && maxVotes > 0
                                ? Colors.red
                                : Colors.white70,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          if (gameService.isHost)
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () => gameService.revealLiar(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.visibility),
                label: const Text(
                  'Reveal the Liar!',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            )
          else
            const Text(
              'Waiting for host to reveal...',
              style: TextStyle(color: Colors.white54),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// REVEAL PHASE - Show who the liar was
// ============================================================================

class _RevealPhase extends StatelessWidget {
  final Room room;
  final GameService gameService;

  const _RevealPhase({required this.room, required this.gameService});

  @override
  Widget build(BuildContext context) {
    final liar = room.liar;
    final liarWasCaught = room.liarWasCaught;
    final correctGuessers = room.playersWhoGuessedCorrectly;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          children: [
            _PhaseHeader(
              title: 'The Truth Revealed!',
              subtitle: liarWasCaught ? 'The liar was caught!' : 'The liar escaped!',
              icon: liarWasCaught ? Icons.celebration : Icons.sentiment_very_satisfied,
            ),
            const SizedBox(height: 32),

            // Liar reveal card
            Card(
              color: Colors.red.withOpacity(0.2),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Text(
                      'THE LIAR WAS',
                      style: TextStyle(
                        color: Colors.white54,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: liar?.avatarColor ?? Colors.red,
                      child: Text(
                        liar?.initials ?? '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 28,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      liar?.name ?? 'Unknown',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Liar's question
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "The Liar's Question:",
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      room.liarQuestion?.question ?? 'Unknown',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Everyone Else Got:',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      room.currentQuestion?.question ?? 'Unknown',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Who guessed correctly
            if (correctGuessers.isNotEmpty) ...[
              Card(
                color: Colors.green.withOpacity(0.2),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.star, color: Colors.green),
                          SizedBox(width: 8),
                          Text(
                            'Correct Guesses',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: correctGuessers.map((player) {
                          return Chip(
                            avatar: CircleAvatar(
                              backgroundColor: player.avatarColor,
                              child: Text(
                                player.initials,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            label: Text(player.name),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await gameService.leaveRoom();
                      if (context.mounted) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => const HomeScreen()),
                        );
                      }
                    },
                    icon: const Icon(Icons.home),
                    label: const Text('Home'),
                  ),
                ),
                const SizedBox(width: 16),
                if (gameService.isHost)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => gameService.playAgain(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.replay),
                      label: const Text('Play Again'),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// SHARED WIDGETS
// ============================================================================

class _PhaseHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _PhaseHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            icon,
            size: 32,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white54,
              ),
        ),
      ],
    );
  }
}
