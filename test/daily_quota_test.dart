import 'package:flutter_test/flutter_test.dart';
import 'package:stirnraten/monetization/daily_quota.dart';

void main() {
  test('DailyQuota.normalize resets used when date key changes', () {
    final normalized = DailyQuota.normalize(
      storedDateKey: '2026-02-10',
      storedUsed: 3,
      todayKey: '2026-02-11',
    );
    expect(normalized.dateKey, '2026-02-11');
    expect(normalized.used, 0);
  });

  test('DailyQuota.normalize keeps used when date key is the same', () {
    final normalized = DailyQuota.normalize(
      storedDateKey: '2026-02-10',
      storedUsed: 2,
      todayKey: '2026-02-10',
    );
    expect(normalized.dateKey, '2026-02-10');
    expect(normalized.used, 2);
  });
}

