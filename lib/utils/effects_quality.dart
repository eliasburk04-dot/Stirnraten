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
      if (total > const Duration(milliseconds: 20)) {
        _slowFrames++;
      }
      if (total > _maxFrame) {
        _maxFrame = total;
      }
    }

    if (_windowFrames < 60) return;

    final slowRatio = _slowFrames / _windowFrames;
    var next = _quality;
    if (slowRatio > 0.35) {
      next = EffectsQuality.low;
    } else if (slowRatio > 0.18) {
      next = EffectsQuality.medium;
    } else if (slowRatio < 0.05) {
      next = EffectsQuality.high;
    }

    if (next != _quality) {
      _quality = next;
      notifyListeners();
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
        return medium ?? (high * 0.66);
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
        return medium ?? (high * 0.7);
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
        return medium ?? (high * 0.7);
      case EffectsQuality.low:
        return low;
    }
  }
}
