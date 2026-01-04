import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import '../data/questions.dart';
import '../data/bomb_party_data.dart';

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
  bool get isLiar => _currentRoom?.liarIds.contains(_currentPlayer?.id) ?? false;
  
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
  Future<bool> createRoom(String playerName, {int liarCount = 1, bool specialRolesEnabled = false, GameType gameType = GameType.liar}) async {
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
        gameType: gameType,
        liarCount: liarCount,
        specialRolesEnabled: specialRolesEnabled,
        minPlayers: gameType == GameType.bombParty ? 2 : 3,
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
    if (_currentRoom!.gameType == GameType.bombParty) {
      await startBombParty();
      return;
    }
    if (!_currentRoom!.canStart) {
      _setError('Need at least ${_currentRoom!.minPlayers} players to start.');
      return;
    }

    try {
      // Get question pair
      final questionPair = getQuestionPair();
      
      // Select random liars based on liarCount
      final players = _currentRoom!.players;
      final liarCount = _currentRoom!.liarCount;
      final specialRoles = _currentRoom!.specialRolesEnabled;
      
      // Shuffle players to pick random liars and roles
      final shuffledPlayers = List<Player>.from(players)..shuffle();
      
      final liarIds = shuffledPlayers.take(liarCount).map((p) => p.id).toList();
      final remainingPlayers = shuffledPlayers.skip(liarCount).toList();
      
      String? detectiveId;
      List<String> accompliceIds = [];

      if (specialRoles) {
        // Assign Detective (from non-liars)
        if (remainingPlayers.isNotEmpty) {
          detectiveId = remainingPlayers.first.id;
        }
        
        // Assign Accomplices (if more than 1 liar)
        if (liarCount > 1) {
          accompliceIds = liarIds; // All liars are accomplices to each other
        }
      }

      // Update room state
      final updates = <String, dynamic>{
        'state': GameState.questioning.name,
        'currentQuestion': questionPair['normal']!.toMap(),
        'liarQuestion': questionPair['liar']!.toMap(),
        'liarIds': liarIds,
        'roundNumber': _currentRoom!.roundNumber + 1,
      };

      // Reset player answers and votes
      for (final player in players) {
        final isLiar = liarIds.contains(player.id);
        PlayerRole role = PlayerRole.normal;
        
        if (player.id == detectiveId) {
          role = PlayerRole.detective;
        } else if (accompliceIds.contains(player.id)) {
          role = PlayerRole.accomplice;
        }

        updates['players/${player.id}/answer'] = null;
        updates['players/${player.id}/votedFor'] = null;
        updates['players/${player.id}/isLiar'] = isLiar;
        updates['players/${player.id}/role'] = role.name;
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
      
      // If a liar was caught, voters who guessed correctly get points
      if (room.liarWasCaught) {
        for (final player in room.playersWhoGuessedCorrectly) {
          scores[player.id] = (scores[player.id] ?? 0) + 1;
        }
      } else {
        // Liars get points if none of them were caught
        for (final liarId in room.liarIds) {
          scores[liarId] = (scores[liarId] ?? 0) + 2;
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
        'liarIds': [],
        'currentSyllable': null,
        'activePlayerId': null,
        'usedWords': [],
        'lives': {},
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
  // BOMB PARTY LOGIC
  // ============================================================================

  /// Start Bomb Party game
  Future<void> startBombParty() async {
    if (!isHost || _currentRoom == null) return;

    try {
      final random = Random();
      final firstSyllable = bombPartySyllables[random.nextInt(bombPartySyllables.length)];
      final firstPlayerId = _currentRoom!.players[random.nextInt(_currentRoom!.players.length)].id;
      
      final lives = <String, int>{};
      for (final player in _currentRoom!.players) {
        lives[player.id] = 3;
      }

      final updates = <String, dynamic>{
        'state': GameState.playing.name,
        'currentSyllable': firstSyllable,
        'activePlayerId': firstPlayerId,
        'lives': lives,
        'usedWords': [],
        'turnEndsAt': DateTime.now().millisecondsSinceEpoch + 15000,
      };

      await _database.ref('rooms/${_currentRoom!.id}').update(updates);
    } catch (e) {
      _setError('Failed to start Bomb Party: $e');
    }
  }

  /// Submit a word in Bomb Party
  Future<bool> submitBombWord(String word) async {
    if (_currentRoom == null || _currentPlayer == null) return false;
    if (_currentRoom!.activePlayerId != _currentPlayer!.id) return false;

    final normalizedWord = word.trim().toUpperCase();
    final syllable = _currentRoom!.currentSyllable?.toUpperCase() ?? '';

    // Validation
    if (!normalizedWord.contains(syllable)) return false;
    if (_currentRoom!.usedWords.contains(normalizedWord)) return false;
    if (normalizedWord.length < 3) return false;

    try {
      final random = Random();
      final nextSyllable = bombPartySyllables[random.nextInt(bombPartySyllables.length)];
      
      // Find next player with lives
      final playersWithLives = _currentRoom!.players.where((p) => (_currentRoom!.lives[p.id] ?? 0) > 0).toList();
      final currentIndex = playersWithLives.indexWhere((p) => p.id == _currentPlayer!.id);
      final nextPlayer = playersWithLives[(currentIndex + 1) % playersWithLives.length];

      final usedWords = List<String>.from(_currentRoom!.usedWords);
      usedWords.add(normalizedWord);

      final updates = <String, dynamic>{
        'currentSyllable': nextSyllable,
        'activePlayerId': nextPlayer.id,
        'usedWords': usedWords,
        'turnEndsAt': DateTime.now().millisecondsSinceEpoch + 15000,
        'currentInput': '', // Clear input for next player
      };

      await _database.ref('rooms/${_currentRoom!.id}').update(updates);
      return true;
    } catch (e) {
      _setError('Failed to submit word: $e');
      return false;
    }
  }

  /// Update current typing input for Bomb Party
  Future<void> updateBombInput(String input) async {
    if (_currentRoom == null || _currentPlayer == null) return;
    if (_currentRoom!.activePlayerId != _currentPlayer!.id) return;

    try {
      await _database.ref('rooms/${_currentRoom!.id}/currentInput').set(input);
    } catch (e) {
      // Silent error for typing sync
    }
  }

  /// Handle bomb explosion (timer reached 0)
  Future<void> handleExplosion() async {
    if (!isHost || _currentRoom == null) return;

    try {
      final activeId = _currentRoom!.activePlayerId;
      if (activeId == null) return;

      final lives = Map<String, int>.from(_currentRoom!.lives);
      lives[activeId] = (lives[activeId] ?? 1) - 1;

      // Check if game over (only one player left with lives)
      final playersWithLives = _currentRoom!.players.where((p) => (lives[p.id] ?? 0) > 0).toList();
      
      final updates = <String, dynamic>{
        'lives': lives,
        'turnEndsAt': DateTime.now().millisecondsSinceEpoch + 15000,
        'currentInput': '', // Clear input
      };

      if (playersWithLives.length <= 1) {
        updates['state'] = GameState.gameOver.name;
      } else {
        // Move to next player
        final currentIndex = _currentRoom!.players.indexWhere((p) => p.id == activeId);
        // Find next player with lives
        int nextIndex = (currentIndex + 1) % _currentRoom!.players.length;
        while ((lives[_currentRoom!.players[nextIndex].id] ?? 0) <= 0) {
          nextIndex = (nextIndex + 1) % _currentRoom!.players.length;
        }
        updates['activePlayerId'] = _currentRoom!.players[nextIndex].id;
        
        // New syllable
        final random = Random();
        updates['currentSyllable'] = bombPartySyllables[random.nextInt(bombPartySyllables.length)];
      }

      await _database.ref('rooms/${_currentRoom!.id}').update(updates);
    } catch (e) {
      _setError('Failed to handle explosion: $e');
    }
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
