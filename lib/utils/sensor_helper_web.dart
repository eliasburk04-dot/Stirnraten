import 'package:js/js.dart';

@JS('requestDeviceMotionPermission')
external dynamic _requestDeviceMotionPermission();

@JS('latestAccelerometerData')
external dynamic get _latestAccelerometerData;

Future<bool> requestSensorPermission() async {
  try {
    final result = _requestDeviceMotionPermission();
    if (result is Future) {
      final v = await result;
      return v == true;
    }
    return result == true;
  } catch (_) {
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
