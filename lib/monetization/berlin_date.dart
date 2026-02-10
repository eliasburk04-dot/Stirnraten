import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Centralized date key handling for daily quotas.
///
/// Requirement: use Europe/Berlin local date (DST-aware), not UTC.
class BerlinDate {
  static bool _initialized = false;
  static tz.Location? _berlin;

  static void ensureInitialized() {
    if (_initialized) return;
    tz.initializeTimeZones();
    _berlin = tz.getLocation('Europe/Berlin');
    _initialized = true;
  }

  static String dateKey({DateTime? now}) {
    ensureInitialized();
    final berlin = _berlin!;
    final instant = now ?? DateTime.now();
    final inBerlin = tz.TZDateTime.from(instant, berlin);
    final y = inBerlin.year.toString().padLeft(4, '0');
    final m = inBerlin.month.toString().padLeft(2, '0');
    final d = inBerlin.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

