import 'dart:math' as math;

enum TiltGestureAction { correct, pass }

enum TiltControllerPhase { idle, calibrating, active, cooldown }

class TiltController {
  TiltController({
    required this.neutralZoneDeg,
    required this.triggerDeg,
    required this.holdMs,
    required this.cooldownMs,
    required this.calibrationMs,
    this.lowPassAlpha = 0.2,
  }) : assert(lowPassAlpha > 0 && lowPassAlpha <= 1);

  final double neutralZoneDeg;
  final double triggerDeg;
  final int holdMs;
  final int cooldownMs;
  final int calibrationMs;
  final double lowPassAlpha;

  TiltControllerPhase _phase = TiltControllerPhase.idle;
  bool _requiresNeutral = true;
  int _calibrationStartMs = 0;
  final List<double> _calibrationAnglesDeg = <double>[];
  double _baselineAngleDeg = 0.0;
  bool _hasSmoothedZ = false;
  double _smoothedZ = 0.0;
  double _lastDeltaDeg = 0.0;
  int? _positiveHoldStartMs;
  int? _negativeHoldStartMs;
  int _cooldownUntilMs = 0;

  TiltControllerPhase get phase => _phase;
  bool get isCalibrating => _phase == TiltControllerPhase.calibrating;
  double get baselineAngleDeg => _baselineAngleDeg;
  double get lastDeltaDeg => _lastDeltaDeg;

  void start(int nowMs) {
    _phase = TiltControllerPhase.calibrating;
    _requiresNeutral = true;
    _calibrationStartMs = nowMs;
    _calibrationAnglesDeg.clear();
    _baselineAngleDeg = 0.0;
    _hasSmoothedZ = false;
    _smoothedZ = 0.0;
    _lastDeltaDeg = 0.0;
    _positiveHoldStartMs = null;
    _negativeHoldStartMs = null;
    _cooldownUntilMs = 0;
  }

  void stop() {
    _phase = TiltControllerPhase.idle;
    _requiresNeutral = true;
    _calibrationAnglesDeg.clear();
    _baselineAngleDeg = 0.0;
    _hasSmoothedZ = false;
    _smoothedZ = 0.0;
    _lastDeltaDeg = 0.0;
    _positiveHoldStartMs = null;
    _negativeHoldStartMs = null;
    _cooldownUntilMs = 0;
  }

  TiltGestureAction? update({
    required double x,
    required double y,
    required double z,
    required int nowMs,
    required bool allowTrigger,
  }) {
    if (_phase == TiltControllerPhase.idle) {
      return null;
    }

    final angleDeg = _computeTiltAngleDeg(x, y, z);
    if (angleDeg == null) {
      return null;
    }

    if (_phase == TiltControllerPhase.calibrating) {
      _calibrationAnglesDeg.add(angleDeg);
      if (nowMs - _calibrationStartMs >= calibrationMs) {
        _finishCalibration();
      }
      return null;
    }

    if (_phase == TiltControllerPhase.cooldown && nowMs < _cooldownUntilMs) {
      return null;
    }
    if (_phase == TiltControllerPhase.cooldown && nowMs >= _cooldownUntilMs) {
      _phase = TiltControllerPhase.active;
    }

    _lastDeltaDeg = angleDeg - _baselineAngleDeg;

    if (_lastDeltaDeg.abs() <= neutralZoneDeg) {
      _requiresNeutral = false;
      _positiveHoldStartMs = null;
      _negativeHoldStartMs = null;
      // Track a slow baseline drift while staying neutral.
      _baselineAngleDeg =
          _baselineAngleDeg + (angleDeg - _baselineAngleDeg) * 0.02;
      return null;
    }

    if (_requiresNeutral) {
      return null;
    }

    if (_lastDeltaDeg >= triggerDeg) {
      _positiveHoldStartMs ??= nowMs;
      _negativeHoldStartMs = null;
      if (nowMs - (_positiveHoldStartMs ?? nowMs) >= holdMs) {
        return _register(TiltGestureAction.pass, nowMs, allowTrigger);
      }
      return null;
    }

    if (_lastDeltaDeg <= -triggerDeg) {
      _negativeHoldStartMs ??= nowMs;
      _positiveHoldStartMs = null;
      if (nowMs - (_negativeHoldStartMs ?? nowMs) >= holdMs) {
        return _register(TiltGestureAction.correct, nowMs, allowTrigger);
      }
      return null;
    }

    _positiveHoldStartMs = null;
    _negativeHoldStartMs = null;
    return null;
  }

  double? _computeTiltAngleDeg(double x, double y, double z) {
    final norm = math.sqrt(x * x + y * y + z * z);
    if (norm <= 0.0001) {
      return null;
    }

    final normalizedZ = (z / norm).clamp(-1.0, 1.0);
    if (!_hasSmoothedZ) {
      _smoothedZ = normalizedZ;
      _hasSmoothedZ = true;
    } else {
      _smoothedZ = _smoothedZ + lowPassAlpha * (normalizedZ - _smoothedZ);
    }

    return math.asin(_smoothedZ) * 180 / math.pi;
  }

  void _finishCalibration() {
    if (_calibrationAnglesDeg.isNotEmpty) {
      _baselineAngleDeg = _median(_calibrationAnglesDeg);
    }
    _phase = TiltControllerPhase.active;
    _requiresNeutral = true;
  }

  TiltGestureAction? _register(
    TiltGestureAction action,
    int nowMs,
    bool allowTrigger,
  ) {
    if (!allowTrigger) {
      return null;
    }
    _phase = TiltControllerPhase.cooldown;
    _cooldownUntilMs = nowMs + cooldownMs;
    _requiresNeutral = true;
    _positiveHoldStartMs = null;
    _negativeHoldStartMs = null;
    return allowTrigger ? action : null;
  }

  double _median(List<double> values) {
    final sorted = List<double>.from(values)..sort();
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) {
      return sorted[mid];
    }
    return (sorted[mid - 1] + sorted[mid]) / 2.0;
  }
}
