class DrinkingBalance {
  final double giveRaw;
  final double takeRaw;
  final double netRaw;
  final int finalGive;
  final int finalTake;
  final int finalNetAbs;
  final bool netIsGive;

  const DrinkingBalance({
    required this.giveRaw,
    required this.takeRaw,
    required this.netRaw,
    required this.finalGive,
    required this.finalTake,
    required this.finalNetAbs,
    required this.netIsGive,
  });

  factory DrinkingBalance.fromCounts({
    required int correctCount,
    required int passCount,
  }) {
    final giveUnits = correctCount;
    final takeUnits = passCount;
    final netUnits = giveUnits - takeUnits;
    final absUnits = netUnits.abs();
    final roundedAbs = _roundHalfUpFromUnits(absUnits);

    final finalGive = netUnits > 0 ? roundedAbs : 0;
    final finalTake = netUnits < 0 ? roundedAbs : 0;

    return DrinkingBalance(
      giveRaw: giveUnits / 2.0,
      takeRaw: takeUnits / 2.0,
      netRaw: netUnits / 2.0,
      finalGive: finalGive,
      finalTake: finalTake,
      finalNetAbs: roundedAbs,
      netIsGive: netUnits > 0,
    );
  }

  static int _roundHalfUpFromUnits(int units) {
    if (units == 0) return 0;
    return (units ~/ 2) + (units.isOdd ? 1 : 0);
  }
}
