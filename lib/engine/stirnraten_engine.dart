import 'dart:math' as math;

enum StirnratenGameState { setup, countdown, playing, result }
enum GameMode { classic, suddenDeath, hardcore, drinking }
enum GameAction { correct, skip }

const int hardcoreSkipPenaltySeconds = 5;
const int drinkingSkipSips = 2;
const int drinkingWrongSips = 1;

class GameResult {
  final String word;
  final bool correct;

  const GameResult({
    required this.word,
    required this.correct,
  });
}

class GameSnapshot {
  final StirnratenGameState state;
  final GameMode selectedMode;
  final GameMode activeMode;
  final int selectedTime;
  final int timeLeft;
  final int countdown;
  final int score;
  final String currentWord;
  final List<String> remainingWords;
  final List<GameResult> results;

  const GameSnapshot({
    required this.state,
    required this.selectedMode,
    required this.activeMode,
    required this.selectedTime,
    required this.timeLeft,
    required this.countdown,
    required this.score,
    required this.currentWord,
    required this.remainingWords,
    required this.results,
  });

  GameSnapshot copyWith({
    StirnratenGameState? state,
    GameMode? selectedMode,
    GameMode? activeMode,
    int? selectedTime,
    int? timeLeft,
    int? countdown,
    int? score,
    String? currentWord,
    List<String>? remainingWords,
    List<GameResult>? results,
  }) {
    return GameSnapshot(
      state: state ?? this.state,
      selectedMode: selectedMode ?? this.selectedMode,
      activeMode: activeMode ?? this.activeMode,
      selectedTime: selectedTime ?? this.selectedTime,
      timeLeft: timeLeft ?? this.timeLeft,
      countdown: countdown ?? this.countdown,
      score: score ?? this.score,
      currentWord: currentWord ?? this.currentWord,
      remainingWords: remainingWords ?? this.remainingWords,
      results: results ?? this.results,
    );
  }
}

class GameActionOutcome {
  final bool accepted;
  final bool shouldEndAfterFeedback;
  final bool outOfTime;

  const GameActionOutcome({
    required this.accepted,
    required this.shouldEndAfterFeedback,
    required this.outOfTime,
  });

  bool get shouldAdvanceWord => accepted && !shouldEndAfterFeedback;
}

class StirnratenEngine {
  GameSnapshot _snapshot = const GameSnapshot(
    state: StirnratenGameState.setup,
    selectedMode: GameMode.classic,
    activeMode: GameMode.classic,
    selectedTime: 90,
    timeLeft: 90,
    countdown: 3,
    score: 0,
    currentWord: '',
    remainingWords: [],
    results: [],
  );

  GameSnapshot get snapshot => _snapshot;

  void setSelectedTime(int seconds) {
    _snapshot = _snapshot.copyWith(
      selectedTime: seconds,
      timeLeft: seconds,
    );
  }

  void setSelectedMode(GameMode mode) {
    _snapshot = _snapshot.copyWith(selectedMode: mode);
  }

  List<String> prepareWordsForMode(List<String> words) {
    if (_snapshot.selectedMode != GameMode.hardcore) {
      return words;
    }
    final hardWords = words.where((word) {
      final trimmed = word.trim();
      return trimmed.length >= 8 ||
          trimmed.contains(' ') ||
          trimmed.contains('-');
    }).toList();
    if (hardWords.length >= 10) {
      return hardWords;
    }
    return words;
  }

  void startCountdown(List<String> words) {
    final prepared = List<String>.from(prepareWordsForMode(words));
    prepared.shuffle(math.Random());
    _snapshot = _snapshot.copyWith(
      state: StirnratenGameState.countdown,
      activeMode: _snapshot.selectedMode,
      remainingWords: prepared,
      score: 0,
      timeLeft: _snapshot.selectedTime,
      results: const [],
      countdown: 3,
      currentWord: '',
    );
  }

  bool tickCountdown() {
    if (_snapshot.state != StirnratenGameState.countdown) {
      return false;
    }
    if (_snapshot.countdown > 1) {
      _snapshot = _snapshot.copyWith(countdown: _snapshot.countdown - 1);
      return false;
    }
    return true;
  }

  void startGame() {
    if (_snapshot.state != StirnratenGameState.countdown) {
      return;
    }
    _snapshot = _snapshot.copyWith(state: StirnratenGameState.playing);
    _advanceWordInternal();
  }

  bool tickTimer() {
    if (_snapshot.state != StirnratenGameState.playing) {
      return false;
    }
    if (_snapshot.timeLeft > 0) {
      final next = _snapshot.timeLeft - 1;
      _snapshot = _snapshot.copyWith(timeLeft: next);
      return next == 0;
    }
    return true;
  }

  GameActionOutcome applyAction(GameAction action) {
    if (_snapshot.state != StirnratenGameState.playing) {
      return const GameActionOutcome(
        accepted: false,
        shouldEndAfterFeedback: false,
        outOfTime: false,
      );
    }

    final results = List<GameResult>.from(_snapshot.results);
    if (action == GameAction.correct) {
      results.add(GameResult(word: _snapshot.currentWord, correct: true));
      _snapshot = _snapshot.copyWith(
        score: _snapshot.score + 1,
        results: results,
      );
      return const GameActionOutcome(
        accepted: true,
        shouldEndAfterFeedback: false,
        outOfTime: false,
      );
    }

    results.add(GameResult(word: _snapshot.currentWord, correct: false));

    if (_snapshot.activeMode == GameMode.suddenDeath) {
      _snapshot = _snapshot.copyWith(results: results);
      return const GameActionOutcome(
        accepted: true,
        shouldEndAfterFeedback: true,
        outOfTime: false,
      );
    }

    if (_snapshot.activeMode == GameMode.hardcore) {
      final nextTime = _snapshot.timeLeft - hardcoreSkipPenaltySeconds;
      final updated = nextTime < 0 ? 0 : nextTime;
      _snapshot = _snapshot.copyWith(
        results: results,
        timeLeft: updated,
      );
      final outOfTime = updated == 0;
      return GameActionOutcome(
        accepted: true,
        shouldEndAfterFeedback: outOfTime,
        outOfTime: outOfTime,
      );
    }

    _snapshot = _snapshot.copyWith(results: results);
    return const GameActionOutcome(
      accepted: true,
      shouldEndAfterFeedback: false,
      outOfTime: false,
    );
  }

  bool advanceWord() {
    if (_snapshot.state != StirnratenGameState.playing) {
      return false;
    }
    return _advanceWordInternal();
  }

  void endGame() {
    _snapshot = _snapshot.copyWith(state: StirnratenGameState.result);
  }

  void resetToSetup() {
    _snapshot = _snapshot.copyWith(state: StirnratenGameState.setup);
  }

  bool _advanceWordInternal() {
    final remaining = List<String>.from(_snapshot.remainingWords);
    if (remaining.isEmpty) {
      _snapshot = _snapshot.copyWith(state: StirnratenGameState.result);
      return false;
    }
    final nextWord = remaining.removeLast();
    _snapshot = _snapshot.copyWith(
      remainingWords: remaining,
      currentWord: nextWord,
    );
    return true;
  }
}
