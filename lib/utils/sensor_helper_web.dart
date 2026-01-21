import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';

@JS('requestDeviceMotionPermission')
external JSPromise<JSBoolean> _requestDeviceMotionPermission();

@JS('latestAccelerometerData')
external JSObject get _latestAccelerometerData;

@JS('tiltDetection.start')
external void _startTiltDetection(
  JSFunction correctCallback,
  JSFunction passCallback,
);

@JS('tiltDetection.stop')
external void _stopTiltDetection();

Future<bool> requestSensorPermission() async {
  try {
    final result = await _requestDeviceMotionPermission().toDart;
    return result.toDart;
  } catch (e) {
    debugPrint('⚠️ requestSensorPermission error: $e');
    return false;
  }
}

List<double> getWebAccelerometerData() {
  try {
    final data = _latestAccelerometerData;
    final x = _readAxisValue(data, 'x');
    final y = _readAxisValue(data, 'y');
    final z = _readAxisValue(data, 'z');
    return [x, y, z];
  } catch (_) {}
  return [0.0, 0.0, 0.0];
}

double _readAxisValue(JSObject data, String key) {
  final value = data.getProperty<JSNumber?>(key.toJS);
  return value?.toDartDouble ?? 0.0;
}

void startWebTiltDetection(Function correctCallback, Function passCallback) {
  try {
    _startTiltDetection(
      (correctCallback as void Function()).toJS,
      (passCallback as void Function()).toJS,
    );
    debugPrint('✅ Web tilt detection started with allowInterop');
  } catch (e) {
    debugPrint('⚠️ Failed to start web tilt detection: $e');
  }
}

void stopWebTiltDetection() {
  try {
    _stopTiltDetection();
    debugPrint('✅ Web tilt detection stopped');
  } catch (e) {
    debugPrint('⚠️ Failed to stop web tilt detection: $e');
  }
}
