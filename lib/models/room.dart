import 'player.dart';
import 'game_state.dart';
import '../data/questions.dart';

/// Represents a game room
class Room {
  final String id;
  final String code;
  final String hostId;
  final List<Player> players;
  final GameState state;
  final Question? currentQuestion;
  final Question? liarQuestion;
  final String? liarId;
  final int roundNumber;
  final int maxPlayers;
  final int minPlayers;
  final DateTime createdAt;
  final int? timerSeconds;
  final Map<String, int> scores; // Player ID -> Score

  const Room({
    required this.id,
    required this.code,
    required this.hostId,
    this.players = const [],
    this.state = GameState.lobby,
    this.currentQuestion,
    this.liarQuestion,
    this.liarId,
    this.roundNumber = 0,
    this.maxPlayers = 10,
    this.minPlayers = 3,
    DateTime? createdAt,
    this.timerSeconds,
    this.scores = const {},
  }) : createdAt = createdAt ?? const _DefaultDateTime();

  /// Create a copy with updated fields
  Room copyWith({
    String? id,
    String? code,
    String? hostId,
    List<Player>? players,
    GameState? state,
    Question? currentQuestion,
    Question? liarQuestion,
    String? liarId,
    int? roundNumber,
    int? maxPlayers,
    int? minPlayers,
    DateTime? createdAt,
    int? timerSeconds,
    Map<String, int>? scores,
  }) {
    return Room(
      id: id ?? this.id,
      code: code ?? this.code,
      hostId: hostId ?? this.hostId,
      players: players ?? this.players,
      state: state ?? this.state,
      currentQuestion: currentQuestion ?? this.currentQuestion,
      liarQuestion: liarQuestion ?? this.liarQuestion,
      liarId: liarId ?? this.liarId,
      roundNumber: roundNumber ?? this.roundNumber,
      maxPlayers: maxPlayers ?? this.maxPlayers,
      minPlayers: minPlayers ?? this.minPlayers,
      createdAt: createdAt ?? this.createdAt,
      timerSeconds: timerSeconds ?? this.timerSeconds,
      scores: scores ?? this.scores,
    );
  }

  /// Convert to Map for Firebase
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code,
      'hostId': hostId,
      'players': {for (var p in players) p.id: p.toMap()},
      'state': state.name,
      'currentQuestion': currentQuestion?.toMap(),
      'liarQuestion': liarQuestion?.toMap(),
      'liarId': liarId,
      'roundNumber': roundNumber,
      'maxPlayers': maxPlayers,
      'minPlayers': minPlayers,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'timerSeconds': timerSeconds,
      'scores': scores,
    };
  }

  /// Create from Map (from Firebase)
  factory Room.fromMap(Map<String, dynamic> map) {
    final playersMap = map['players'] as Map<dynamic, dynamic>? ?? {};
    final players = playersMap.entries
        .map((e) => Player.fromMap(Map<String, dynamic>.from(e.value as Map)))
        .toList();

    final scoresMap = map['scores'] as Map<dynamic, dynamic>? ?? {};
    final scores = scoresMap.map((key, value) => 
        MapEntry(key.toString(), value as int));

    return Room(
      id: map['id'] as String,
      code: map['code'] as String,
      hostId: map['hostId'] as String,
      players: players,
      state: GameState.values.firstWhere(
        (e) => e.name == map['state'],
        orElse: () => GameState.lobby,
      ),
      currentQuestion: map['currentQuestion'] != null
          ? Question.fromMap(Map<String, dynamic>.from(map['currentQuestion'] as Map))
          : null,
      liarQuestion: map['liarQuestion'] != null
          ? Question.fromMap(Map<String, dynamic>.from(map['liarQuestion'] as Map))
          : null,
      liarId: map['liarId'] as String?,
      roundNumber: map['roundNumber'] as int? ?? 0,
      maxPlayers: map['maxPlayers'] as int? ?? 10,
      minPlayers: map['minPlayers'] as int? ?? 3,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        map['createdAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      ),
      timerSeconds: map['timerSeconds'] as int?,
      scores: Map<String, int>.from(scores),
    );
  }

  /// Check if room is full
  bool get isFull => players.length >= maxPlayers;

  /// Check if room has enough players to start
  bool get canStart => players.length >= minPlayers;

  /// Get the host player
  Player? get host => players.where((p) => p.id == hostId).firstOrNull;

  /// Get the liar player
  Player? get liar => players.where((p) => p.id == liarId).firstOrNull;

  /// Get players who have answered
  List<Player> get playersWhoAnswered => 
      players.where((p) => p.hasAnswered).toList();

  /// Get players who have voted
  List<Player> get playersWhoVoted => 
      players.where((p) => p.hasVoted).toList();

  /// Check if all players have answered
  bool get allAnswered => players.every((p) => p.hasAnswered);

  /// Check if all players have voted
  bool get allVoted => players.every((p) => p.hasVoted);

  /// Get vote counts for each player
  Map<String, int> get voteCounts {
    final counts = <String, int>{};
    for (final player in players) {
      counts[player.id] = players.where((p) => p.votedFor == player.id).length;
    }
    return counts;
  }

  /// Get the player with most votes
  Player? get mostVotedPlayer {
    if (players.isEmpty) return null;
    final counts = voteCounts;
    final maxVotes = counts.values.reduce((a, b) => a > b ? a : b);
    final mostVotedId = counts.entries
        .where((e) => e.value == maxVotes)
        .map((e) => e.key)
        .first;
    return players.where((p) => p.id == mostVotedId).firstOrNull;
  }

  /// Check if the liar was caught
  bool get liarWasCaught => mostVotedPlayer?.id == liarId;

  /// Get players who correctly identified the liar
  List<Player> get playersWhoGuessedCorrectly =>
      players.where((p) => p.votedFor == liarId).toList();

  @override
  String toString() => 'Room(code: $code, players: ${players.length}, state: $state)';
}

/// Helper class for default DateTime
class _DefaultDateTime implements DateTime {
  const _DefaultDateTime();
  
  @override
  dynamic noSuchMethod(Invocation invocation) => DateTime.now().noSuchMethod(invocation);
}
