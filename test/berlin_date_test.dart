import 'package:flutter_test/flutter_test.dart';
import 'package:stirnraten/monetization/berlin_date.dart';

void main() {
  test('BerlinDate.dateKey uses Europe/Berlin date (CET)', () {
    // 23:30 UTC on Feb 10 -> 00:30 in Berlin (CET) on Feb 11.
    final key = BerlinDate.dateKey(now: DateTime.utc(2026, 2, 10, 23, 30));
    expect(key, '2026-02-11');
  });

  test('BerlinDate.dateKey uses Europe/Berlin date (CEST)', () {
    // 22:30 UTC on Jun 10 -> 00:30 in Berlin (CEST) on Jun 11.
    final key = BerlinDate.dateKey(now: DateTime.utc(2026, 6, 10, 22, 30));
    expect(key, '2026-06-11');
  });
}

