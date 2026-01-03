import 'package:js/js.dart';
import 'dart:js_util';

@JS('requestDeviceMotionPermission')
external dynamic _requestDeviceMotionPermission();

@JS('latestAccelerometerData')
external dynamic get _latestAccelerometerData;

@JS('tiltDetection.start')
external void _startTiltDetection(Function correctCallback, Function passCallback);

@JS('tiltDetection.stop')
external void _stopTiltDetection();

@JS('tiltDetection.isActive')
external bool get _isTiltDetectionActive;

Future<bool> requestSensorPermission() async {
  try {
    final result = _requestDeviceMotionPermission();
    if (result is Future) {
      final v = await result;
      return v == true;
    }
    // Handle Promise from JS
    if (result != null) {
      try {
        final promiseResult = await promiseToFuture(result);
        return promiseResult == true;
      } catch (_) {
        return result == true;
      }
    }
    return result == true;
  } catch (e) {
    print('⚠️ requestSensorPermission error: $e');
    return false;
  }
}

List<double> getWebAccelerometerData() {
  try {
    final data = _latestAccelerometerData;
    if (data != null) {
      final x = data.x;
      final y = data.y;
      final z = data.z;
      return [
        (x as num).toDouble(),
        (y as num).toDouble(),
        (z as num).toDouble(),
      ];
    }
  } catch (_) {}
  return [0.0, 0.0, 0.0];
}

void startWebTiltDetection(Function correctCallback, Function passCallback) {
  try {
    // IMPORTANT: Use allowInterop to make Dart functions callable from JavaScript
    _startTiltDetection(
      allowInterop(correctCallback),
      allowInterop(passCallback),
    );
    print('✅ Web tilt detection started with allowInterop');
  } catch (e) {
    print('⚠️ Failed to start web tilt detection: $e');
  }
}

void stopWebTiltDetection() {
  try {
    _stopTiltDetection();
    print('✅ Web tilt detection stopped');
  } catch (e) {
    print('⚠️ Failed to stop web tilt detection: $e');
  }
}
