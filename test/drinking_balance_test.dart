import 'package:flutter_test/flutter_test.dart';

import 'package:stirnraten/engine/drinking_balance.dart';

void main() {
  test('drinking balance: zero case', () {
    final balance = DrinkingBalance.fromCounts(correctCount: 0, passCount: 0);
    expect(balance.finalGive, 0);
    expect(balance.finalTake, 0);
    expect(balance.finalNetAbs, 0);
  });

  test('drinking balance: correct 1 => 0.5 rounds up to 1 give', () {
    final balance = DrinkingBalance.fromCounts(correctCount: 1, passCount: 0);
    expect(balance.finalGive, 1);
    expect(balance.finalTake, 0);
  });

  test('drinking balance: correct 2 => 1.0 give', () {
    final balance = DrinkingBalance.fromCounts(correctCount: 2, passCount: 0);
    expect(balance.finalGive, 1);
    expect(balance.finalTake, 0);
  });

  test('drinking balance: correct 3 => 1.5 rounds up to 2 give', () {
    final balance = DrinkingBalance.fromCounts(correctCount: 3, passCount: 0);
    expect(balance.finalGive, 2);
    expect(balance.finalTake, 0);
  });

  test('drinking balance: correct 2 pass 1 => net 0.5 give', () {
    final balance = DrinkingBalance.fromCounts(correctCount: 2, passCount: 1);
    expect(balance.finalGive, 1);
    expect(balance.finalTake, 0);
  });

  test('drinking balance: correct 1 pass 3 => net -1.0 take', () {
    final balance = DrinkingBalance.fromCounts(correctCount: 1, passCount: 3);
    expect(balance.finalGive, 0);
    expect(balance.finalTake, 1);
  });
}
