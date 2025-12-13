/// Game state enum representing the current phase of the game
enum GameState {
  lobby,      // Waiting for players to join
  questioning, // Question is being displayed
  answering,   // Players are submitting answers
  waiting,     // Waiting for all answers
  voting,      // Players voting on who the liar is
  results,     // Showing results before reveal
  reveal,      // Revealing the liar
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
        return 'Waiting for everyone to answer...';
      case GameState.voting:
        return 'Who do you think had a different question?';
      case GameState.results:
        return 'See how everyone voted';
      case GameState.reveal:
        return 'The truth is revealed!';
    }
  }
}
