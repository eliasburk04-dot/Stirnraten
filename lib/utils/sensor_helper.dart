import 'sensor_helper_stub.dart'
    if (dart.library.html) 'sensor_helper_web.dart' as impl;

Future<bool> requestSensorPermission() => impl.requestSensorPermission();

List<double> getWebAccelerometerData() => impl.getWebAccelerometerData();

bool getWebSensorAvailable() => impl.getWebSensorAvailable();

bool isTiltPermissionRequired() => impl.isTiltPermissionRequired();

void startWebTiltDetection(Function correctCallback, Function passCallback) =>
    impl.startWebTiltDetection(correctCallback, passCallback);

void stopWebTiltDetection() => impl.stopWebTiltDetection();
