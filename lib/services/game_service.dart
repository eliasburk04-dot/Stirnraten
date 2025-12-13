import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import '../data/questions.dart';

/// Service class for managing game state and Firebase synchronization
class GameService extends ChangeNotifier {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final Uuid _uuid = const Uuid();
  
  Room? _currentRoom;
  Player? _currentPlayer;
  StreamSubscription<DatabaseEvent>? _roomSubscription;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  Room? get currentRoom => _currentRoom;
  Player? get currentPlayer => _currentPlayer;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isHost => _currentPlayer?.id == _currentRoom?.hostId;
  bool get isLiar => _currentPlayer?.id == _currentRoom?.liarId;
  
  /// Get the question for the current player (different for liar)
  Question? get myQuestion {
    if (_currentRoom == null) return null;
    if (isLiar) {
      return _currentRoom!.liarQuestion;
    }
    return _currentRoom!.currentQuestion;
  }

  // ============================================================================
  // ROOM MANAGEMENT
  // ============================================================================

  /// Generate a unique 6-character room code
  String _generateRoomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Removed confusing chars
    final random = Random();
    return List.generate(6, (index) => chars[random.nextInt(chars.length)]).join();
  }

  /// Create a new room and become the host
  Future<bool> createRoom(String playerName) async {
    _setLoading(true);
    _clearError();

    try {
      final roomId = _uuid.v4();
      final roomCode = _generateRoomCode();
      final playerId = _uuid.v4();

      // Create host player
      final host = Player(
        id: playerId,
        name: playerName,
        isHost: true,
        avatarColor: getRandomAvatarColor(),
      );

      // Create room
      final room = Room(
        id: roomId,
        code: roomCode,
        hostId: playerId,
        players: [host],
        state: GameState.lobby,
        createdAt: DateTime.now(),
      );

      // Save to Firebase
      await _database.ref('rooms/$roomId').set(room.toMap());

      _currentPlayer = host;
      _currentRoom = room;

      // Start listening for room updates
      _subscribeToRoom(roomId);

      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Failed to create room: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Join an existing room with the given code
  Future<bool> joinRoom(String roomCode, String playerName) async {
    _setLoading(true);
    _clearError();

    try {
      // Find room by code
      final snapshot = await _database
          .ref('rooms')
          .orderByChild('code')
          .equalTo(roomCode.toUpperCase())
          .get();

      if (!snapshot.exists) {
        _setError('Room not found. Check the code and try again.');
        _setLoading(false);
        return false;
      }

      // Get room data
      final roomData = (snapshot.value as Map).values.first as Map;
      final room = Room.fromMap(Map<String, dynamic>.from(roomData));

      // Check if room is full
      if (room.isFull) {
        _setError('Room is full.');
        _setLoading(false);
        return false;
      }

      // Check if game already started
      if (room.state != GameState.lobby) {
        _setError('Game has already started.');
        _setLoading(false);
        return false;
      }

      // Create new player
      final playerId = _uuid.v4();
      final player = Player(
        id: playerId,
        name: playerName,
        isHost: false,
        avatarColor: getRandomAvatarColor(),
      );

      // Add player to room
      await _database.ref('rooms/${room.id}/players/$playerId').set(player.toMap());

      _currentPlayer = player;
      _currentRoom = room;

      // Start listening for room updates
      _subscribeToRoom(room.id);

      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Failed to join room: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Subscribe to real-time room updates
  void _subscribeToRoom(String roomId) {
    _roomSubscription?.cancel();
    _roomSubscription = _database.ref('rooms/$roomId').onValue.listen(
      (event) {
        if (event.snapshot.exists) {
          final data = Map<String, dynamic>.from(event.snapshot.value as Map);
          _currentRoom = Room.fromMap(data);
          
          // Update current player reference
          if (_currentPlayer != null) {
            _currentPlayer = _currentRoom!.players
                .where((p) => p.id == _currentPlayer!.id)
                .firstOrNull;
          }
          
          notifyListeners();
        }
      },
      onError: (error) {
        _setError('Connection error: $error');
      },
    );
  }

  /// Leave the current room
  Future<void> leaveRoom() async {
    if (_currentRoom == null || _currentPlayer == null) return;

    try {
      final roomId = _currentRoom!.id;
      final playerId = _currentPlayer!.id;

      // If host leaves, delete the room
      if (isHost) {
        await _database.ref('rooms/$roomId').remove();
      } else {
        // Remove player from room
        await _database.ref('rooms/$roomId/players/$playerId').remove();
      }

      _cleanup();
    } catch (e) {
      _setError('Failed to leave room: $e');
    }
  }

  /// Kick a player from the room (host only)
  Future<void> kickPlayer(String playerId) async {
    if (!isHost || _currentRoom == null) return;

    try {
      await _database.ref('rooms/${_currentRoom!.id}/players/$playerId').remove();
    } catch (e) {
      _setError('Failed to kick player: $e');
    }
  }

  // ============================================================================
  // GAME FLOW
  // ============================================================================

  /// Start the game (host only)
  Future<void> startGame() async {
    if (!isHost || _currentRoom == null) return;
    if (!_currentRoom!.canStart) {
      _setError('Need at least ${_currentRoom!.minPlayers} players to start.');
      return;
    }

    try {
      // Get question pair
      final questionPair = getQuestionPair();
      
      // Select random liar
      final players = _currentRoom!.players;
      final liarIndex = Random().nextInt(players.length);
      final liarId = players[liarIndex].id;

      // Update room state
      final updates = <String, dynamic>{
        'state': GameState.questioning.name,
        'currentQuestion': questionPair['normal']!.toMap(),
        'liarQuestion': questionPair['liar']!.toMap(),
        'liarId': liarId,
        'roundNumber': _currentRoom!.roundNumber + 1,
      };

      // Reset player answers and votes
      for (final player in players) {
        updates['players/${player.id}/answer'] = null;
        updates['players/${player.id}/votedFor'] = null;
        updates['players/${player.id}/isLiar'] = player.id == liarId;
      }

      await _database.ref('rooms/${_currentRoom!.id}').update(updates);
    } catch (e) {
      _setError('Failed to start game: $e');
    }
  }

  /// Move to answering phase (host only)
  Future<void> startAnswering() async {
    if (!isHost || _currentRoom == null) return;

    try {
      await _database.ref('rooms/${_currentRoom!.id}/state').set(GameState.answering.name);
    } catch (e) {
      _setError('Failed to start answering: $e');
    }
  }

  /// Submit an answer
  Future<void> submitAnswer(String answer) async {
    if (_currentRoom == null || _currentPlayer == null) return;

    try {
      await _database
          .ref('rooms/${_currentRoom!.id}/players/${_currentPlayer!.id}/answer')
          .set(answer);

      // Check if all players have answered
      // This will be detected through the room subscription
    } catch (e) {
      _setError('Failed to submit answer: $e');
    }
  }

  /// Move to voting phase (host only, or automatically when all answered)
  Future<void> startVoting() async {
    if (_currentRoom == null) return;

    try {
      await _database.ref('rooms/${_currentRoom!.id}/state').set(GameState.voting.name);
    } catch (e) {
      _setError('Failed to start voting: $e');
    }
  }

  /// Submit a vote for who the liar is
  Future<void> submitVote(String votedPlayerId) async {
    if (_currentRoom == null || _currentPlayer == null) return;

    try {
      await _database
          .ref('rooms/${_currentRoom!.id}/players/${_currentPlayer!.id}/votedFor')
          .set(votedPlayerId);
    } catch (e) {
      _setError('Failed to submit vote: $e');
    }
  }

  /// Move to results phase
  Future<void> showResults() async {
    if (_currentRoom == null) return;

    try {
      await _database.ref('rooms/${_currentRoom!.id}/state').set(GameState.results.name);
    } catch (e) {
      _setError('Failed to show results: $e');
    }
  }

  /// Move to reveal phase
  Future<void> revealLiar() async {
    if (_currentRoom == null) return;

    try {
      // Update scores
      final updates = <String, dynamic>{
        'state': GameState.reveal.name,
      };

      // Award points
      final room = _currentRoom!;
      final scores = Map<String, int>.from(room.scores);
      
      // If liar was caught, voters who guessed correctly get points
      if (room.liarWasCaught) {
        for (final player in room.playersWhoGuessedCorrectly) {
          scores[player.id] = (scores[player.id] ?? 0) + 1;
        }
      } else {
        // Liar gets points if not caught
        if (room.liarId != null) {
          scores[room.liarId!] = (scores[room.liarId!] ?? 0) + 2;
        }
      }

      updates['scores'] = scores;

      await _database.ref('rooms/${_currentRoom!.id}').update(updates);
    } catch (e) {
      _setError('Failed to reveal liar: $e');
    }
  }

  /// Start a new round (returns to lobby for next round)
  Future<void> playAgain() async {
    if (!isHost || _currentRoom == null) return;

    try {
      final updates = <String, dynamic>{
        'state': GameState.lobby.name,
        'currentQuestion': null,
        'liarQuestion': null,
        'liarId': null,
      };

      // Reset player answers and votes
      for (final player in _currentRoom!.players) {
        updates['players/${player.id}/answer'] = null;
        updates['players/${player.id}/votedFor'] = null;
        updates['players/${player.id}/isLiar'] = false;
      }

      await _database.ref('rooms/${_currentRoom!.id}').update(updates);
    } catch (e) {
      _setError('Failed to start new round: $e');
    }
  }

  /// End the game and return to home
  Future<void> endGame() async {
    await leaveRoom();
  }

  // ============================================================================
  // HELPERS
  // ============================================================================

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }

  void clearError() {
    _clearError();
    notifyListeners();
  }

  void _cleanup() {
    _roomSubscription?.cancel();
    _roomSubscription = null;
    _currentRoom = null;
    _currentPlayer = null;
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _roomSubscription?.cancel();
    super.dispose();
  }
}
