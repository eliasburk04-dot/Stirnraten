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
  final GameType gameType;
  final Question? currentQuestion;
  final Question? liarQuestion;
  final List<String> liarIds;
  final int roundNumber;
  final int maxPlayers;
  final int minPlayers;
  final int liarCount;
  final bool specialRolesEnabled;
  final DateTime createdAt;
  final int? timerSeconds;
  final Map<String, int> scores; // Player ID -> Score
  
  // Bomb Party specific fields
  final String? currentSyllable;
  final String? activePlayerId;
  final List<String> usedWords;
  final Map<String, int> lives; // Player ID -> Lives
  final int? turnEndsAt; // Timestamp in ms
  final String? currentInput; // Real-time typing sync

  const Room({
    required this.id,
    required this.code,
    required this.hostId,
    this.players = const [],
    this.state = GameState.lobby,
    this.gameType = GameType.liar,
    this.currentQuestion,
    this.liarQuestion,
    this.liarIds = const [],
    this.roundNumber = 0,
    this.maxPlayers = 10,
    this.minPlayers = 3,
    this.liarCount = 1,
    this.specialRolesEnabled = false,
    DateTime? createdAt,
    this.timerSeconds,
    this.scores = const {},
    this.currentSyllable,
    this.activePlayerId,
    this.usedWords = const [],
    this.lives = const {},
    this.turnEndsAt,
    this.currentInput,
  }) : createdAt = createdAt ?? const _DefaultDateTime();

  /// Create a copy with updated fields
  Room copyWith({
    String? id,
    String? code,
    String? hostId,
    List<Player>? players,
    GameState? state,
    GameType? gameType,
    Question? currentQuestion,
    Question? liarQuestion,
    List<String>? liarIds,
    int? roundNumber,
    int? maxPlayers,
    int? minPlayers,
    int? liarCount,
    bool? specialRolesEnabled,
    DateTime? createdAt,
    int? timerSeconds,
    Map<String, int>? scores,
    String? currentSyllable,
    String? activePlayerId,
    List<String>? usedWords,
    Map<String, int>? lives,
    int? turnEndsAt,
    String? currentInput,
  }) {
    return Room(
      id: id ?? this.id,
      code: code ?? this.code,
      hostId: hostId ?? this.hostId,
      players: players ?? this.players,
      state: state ?? this.state,
      gameType: gameType ?? this.gameType,
      currentQuestion: currentQuestion ?? this.currentQuestion,
      liarQuestion: liarQuestion ?? this.liarQuestion,
      liarIds: liarIds ?? this.liarIds,
      roundNumber: roundNumber ?? this.roundNumber,
      maxPlayers: maxPlayers ?? this.maxPlayers,
      minPlayers: minPlayers ?? this.minPlayers,
      liarCount: liarCount ?? this.liarCount,
      specialRolesEnabled: specialRolesEnabled ?? this.specialRolesEnabled,
      createdAt: createdAt ?? this.createdAt,
      timerSeconds: timerSeconds ?? this.timerSeconds,
      scores: scores ?? this.scores,
      currentSyllable: currentSyllable ?? this.currentSyllable,
      activePlayerId: activePlayerId ?? this.activePlayerId,
      usedWords: usedWords ?? this.usedWords,
      lives: lives ?? this.lives,
      turnEndsAt: turnEndsAt ?? this.turnEndsAt,
      currentInput: currentInput ?? this.currentInput,
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
      'gameType': gameType.name,
      'currentQuestion': currentQuestion?.toMap(),
      'liarQuestion': liarQuestion?.toMap(),
      'liarIds': liarIds,
      'roundNumber': roundNumber,
      'maxPlayers': maxPlayers,
      'minPlayers': minPlayers,
      'liarCount': liarCount,
      'specialRolesEnabled': specialRolesEnabled,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'timerSeconds': timerSeconds,
      'scores': scores,
      'currentSyllable': currentSyllable,
      'activePlayerId': activePlayerId,
      'usedWords': usedWords,
      'lives': lives,
      'turnEndsAt': turnEndsAt,
      'currentInput': currentInput,
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
        MapEntry(key.toString(), value as int),);

    final livesMap = map['lives'] as Map<dynamic, dynamic>? ?? {};
    final lives = livesMap.map((key, value) => 
        MapEntry(key.toString(), value as int),);

    return Room(
      id: map['id'] as String,
      code: map['code'] as String,
      hostId: map['hostId'] as String,
      players: players,
      state: GameState.values.firstWhere(
        (e) => e.name == map['state'],
        orElse: () => GameState.lobby,
      ),
      gameType: GameType.values.firstWhere(
        (e) => e.name == map['gameType'],
        orElse: () => GameType.liar,
      ),
      currentQuestion: map['currentQuestion'] != null
          ? Question.fromMap(Map<String, dynamic>.from(map['currentQuestion'] as Map))
          : null,
      liarQuestion: map['liarQuestion'] != null
          ? Question.fromMap(Map<String, dynamic>.from(map['liarQuestion'] as Map))
          : null,
      liarIds: map['liarIds'] != null ? List<String>.from(map['liarIds'] as List) : [],
      roundNumber: map['roundNumber'] as int? ?? 0,
      maxPlayers: map['maxPlayers'] as int? ?? 10,
      minPlayers: map['minPlayers'] as int? ?? 3,
      liarCount: map['liarCount'] as int? ?? 1,
      specialRolesEnabled: map['specialRolesEnabled'] as bool? ?? false,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        map['createdAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      ),
      timerSeconds: map['timerSeconds'] as int?,
      scores: Map<String, int>.from(scores),
      currentSyllable: map['currentSyllable'] as String?,
      activePlayerId: map['activePlayerId'] as String?,
      usedWords: map['usedWords'] != null ? List<String>.from(map['usedWords'] as List) : [],
      lives: Map<String, int>.from(lives),
      turnEndsAt: map['turnEndsAt'] as int?,
      currentInput: map['currentInput'] as String?,
    );
  }

  /// Check if room is full
  bool get isFull => players.length >= maxPlayers;

  /// Check if room has enough players to start
  bool get canStart => players.length >= minPlayers;

  /// Get the host player
  Player? get host => players.where((p) => p.id == hostId).firstOrNull;

  /// Get the liar players
  List<Player> get liars => players.where((p) => liarIds.contains(p.id)).toList();

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

  /// Get votes for a specific player
  int getVotesFor(String playerId) {
    return players.where((p) => p.votedFor == playerId).length;
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

  /// Check if a liar was caught
  bool get liarWasCaught {
    final mostVoted = mostVotedPlayer;
    if (mostVoted == null) return false;
    return liarIds.contains(mostVoted.id);
  }

  /// Get players who correctly identified a liar
  List<Player> get playersWhoGuessedCorrectly =>
      players.where((p) => liarIds.contains(p.votedFor)).toList();

  @override
  String toString() => 'Room(code: $code, players: ${players.length}, state: $state)';
}

/// Helper class for default DateTime
class _DefaultDateTime implements DateTime {
  const _DefaultDateTime();
  
  @override
  dynamic noSuchMethod(Invocation invocation) => DateTime.now().noSuchMethod(invocation);
}
