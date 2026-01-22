import 'package:flutter_test/flutter_test.dart';

import 'package:stirnraten/engine/stirnraten_engine.dart';
import 'package:stirnraten/data/words.dart';

void main() {
  test('classic flow: countdown -> play -> correct -> end', () {
    final engine = StirnratenEngine();
    engine.setSelectedMode(GameMode.classic);
    engine.setSelectedTime(30);

    engine.startCountdown(['Alpha']);
    expect(engine.snapshot.state, StirnratenGameState.countdown);
    expect(engine.snapshot.countdown, 3);

    expect(engine.tickCountdown(), isFalse);
    expect(engine.snapshot.countdown, 2);
    expect(engine.tickCountdown(), isFalse);
    expect(engine.snapshot.countdown, 1);
    expect(engine.tickCountdown(), isTrue);

    engine.startGame();
    expect(engine.snapshot.state, StirnratenGameState.playing);
    expect(engine.snapshot.currentWord, 'Alpha');

    final outcome = engine.applyAction(GameAction.correct);
    expect(outcome.accepted, isTrue);
    expect(engine.snapshot.score, 1);
    expect(engine.snapshot.results.length, 1);
    expect(engine.snapshot.results.first.correct, isTrue);

    final advanced = engine.advanceWord();
    expect(advanced, isFalse);
    expect(engine.snapshot.state, StirnratenGameState.result);
  });

  test('timer does not underflow', () {
    final engine = StirnratenEngine();
    engine.setSelectedTime(1);
    engine.startCountdown(['Alpha', 'Beta']);
    engine.tickCountdown();
    engine.tickCountdown();
    engine.tickCountdown();
    engine.startGame();

    expect(engine.snapshot.timeLeft, 1);
    expect(engine.tickTimer(), isTrue);
    expect(engine.snapshot.timeLeft, 0);
    expect(engine.tickTimer(), isTrue);
    expect(engine.snapshot.timeLeft, 0);
  });

  test('hardcore skip applies penalty and signals end', () {
    final engine = StirnratenEngine();
    engine.setSelectedMode(GameMode.hardcore);
    engine.setSelectedTime(4);
    engine.startCountdown(['Alpha', 'Beta']);
    engine.tickCountdown();
    engine.tickCountdown();
    engine.tickCountdown();
    engine.startGame();

    final outcome = engine.applyAction(GameAction.skip);
    expect(outcome.accepted, isTrue);
    expect(outcome.outOfTime, isTrue);
    expect(outcome.shouldEndAfterFeedback, isTrue);
    expect(engine.snapshot.timeLeft, 0);
  });

  test('sudden death skip ends round', () {
    final engine = StirnratenEngine();
    engine.setSelectedMode(GameMode.suddenDeath);
    engine.startCountdown(['Alpha', 'Beta']);
    engine.tickCountdown();
    engine.tickCountdown();
    engine.tickCountdown();
    engine.startGame();

    final outcome = engine.applyAction(GameAction.skip);
    expect(outcome.accepted, isTrue);
    expect(outcome.shouldEndAfterFeedback, isTrue);
    expect(outcome.outOfTime, isFalse);
  });

  test('category word lists are stable', () {
    for (final category in StirnratenCategory.values) {
      final list = StirnratenData.getWords(category);
      if (category == StirnratenCategory.ownWords) {
        expect(list, isEmpty);
      } else {
        expect(list, isNotEmpty);
      }
    }
  });
}
