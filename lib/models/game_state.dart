/// Game type enum
enum GameType {
  liar,
  bombParty,
}

/// Game state enum representing the current phase of the game
enum GameState {
  lobby,      // Waiting for players to join
  // Liar specific states
  questioning, 
  answering,   
  waiting,     
  voting,      
  results,     
  reveal,      
  // Bomb Party specific states
  playing,
  gameOver,
}

extension GameStateExtension on GameState {
  String get displayName {
    switch (this) {
      case GameState.lobby:
        return 'Lobby';
      case GameState.questioning:
        return 'Question Time';
      case GameState.answering:
        return 'Answer Time';
      case GameState.waiting:
        return 'Waiting...';
      case GameState.voting:
        return 'Vote!';
      case GameState.results:
        return 'Results';
      case GameState.reveal:
        return 'Reveal';
      case GameState.playing:
        return 'Playing';
      case GameState.gameOver:
        return 'Game Over';
    }
  }

  String get instruction {
    switch (this) {
      case GameState.lobby:
        return 'Waiting for players to join...';
      case GameState.questioning:
        return 'Read the question carefully!';
      case GameState.answering:
        return 'Enter your answer';
      case GameState.waiting:
        return 'Waiting for others...';
      case GameState.voting:
        return 'Who is the liar?';
      case GameState.results:
        return 'The results are in!';
      case GameState.reveal:
        return 'The truth is revealed!';
      case GameState.playing:
        return 'Your turn!';
      case GameState.gameOver:
        return 'Game Over!';
    }
  }
}
