import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

enum EffectsQuality { high, medium, low }

class EffectsController extends ChangeNotifier {
  EffectsQuality _quality = EffectsQuality.high;
  bool _monitoring = false;
  int _windowFrames = 0;
  int _slowFrames = 0;
  Duration _maxFrame = Duration.zero;
  int _lastChangeMs = 0;
  static const int _sampleWindow = 30;
  static const Duration _slowFrameThreshold = Duration(milliseconds: 18);
  static const Duration _minChangeInterval = Duration(seconds: 4);

  EffectsQuality get quality => _quality;

  void startMonitoring() {
    if (_monitoring) return;
    _monitoring = true;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  void _onTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      final total = timing.totalSpan;
      _windowFrames++;
      if (total > _slowFrameThreshold) {
        _slowFrames++;
      }
      if (total > _maxFrame) {
        _maxFrame = total;
      }
    }

    if (_windowFrames < _sampleWindow) return;

    final slowRatio = _slowFrames / _windowFrames;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs - _lastChangeMs >= _minChangeInterval.inMilliseconds) {
      var next = _quality;
      switch (_quality) {
        case EffectsQuality.high:
          if (slowRatio > 0.22) {
            next = EffectsQuality.medium;
          }
          break;
        case EffectsQuality.medium:
          if (slowRatio > 0.32) {
            next = EffectsQuality.low;
          } else if (slowRatio < 0.08) {
            next = EffectsQuality.high;
          }
          break;
        case EffectsQuality.low:
          if (slowRatio < 0.15) {
            next = EffectsQuality.medium;
          }
          break;
      }

      if (next != _quality) {
        _quality = next;
        _lastChangeMs = nowMs;
        notifyListeners();
      }
    }

    if (kDebugMode) {
      debugPrint(
        'Perf: frames=$_windowFrames slow=$_slowFrames '
        'max=${_maxFrame.inMilliseconds}ms quality=$_quality',
      );
    }

    _windowFrames = 0;
    _slowFrames = 0;
    _maxFrame = Duration.zero;
  }
}

class EffectsConfig {
  final EffectsQuality quality;
  final bool reduceMotion;

  const EffectsConfig({
    required this.quality,
    required this.reduceMotion,
  });

  static EffectsConfig of(BuildContext context) {
    final controller = context.watch<EffectsController>();
    final media = MediaQuery.of(context);
    final accessibility =
        WidgetsBinding.instance.platformDispatcher.accessibilityFeatures;
    final reduceMotion = media.disableAnimations ||
        media.accessibleNavigation ||
        accessibility.reduceMotion;
    final quality = reduceMotion ? EffectsQuality.low : controller.quality;
    return EffectsConfig(quality: quality, reduceMotion: reduceMotion);
  }

  double blur({
    required double high,
    double? medium,
    double low = 0,
  }) {
    switch (quality) {
      case EffectsQuality.high:
        return high;
      case EffectsQuality.medium:
        return medium ?? (high * 0.5);
      case EffectsQuality.low:
        return low;
    }
  }

  double shadowBlur({
    required double high,
    double? medium,
    double low = 0,
  }) {
    switch (quality) {
      case EffectsQuality.high:
        return high;
      case EffectsQuality.medium:
        return medium ?? (high * 0.55);
      case EffectsQuality.low:
        return low;
    }
  }

  double shadowAlpha({
    required double high,
    double? medium,
    double low = 0,
  }) {
    switch (quality) {
      case EffectsQuality.high:
        return high;
      case EffectsQuality.medium:
        return medium ?? (high * 0.6);
      case EffectsQuality.low:
        return low;
    }
  }

  bool get allowBlur => quality != EffectsQuality.low && !reduceMotion;
  bool get allowHeavyEffects => quality == EffectsQuality.high && !reduceMotion;
}
