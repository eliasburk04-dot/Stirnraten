Future<bool> requestSensorPermission() async => false;

List<double> getWebAccelerometerData() => [0.0, 0.0, 0.0];

bool getWebSensorAvailable() => false;

bool isTiltPermissionRequired() => false;

void startWebTiltDetection(Function correctCallback, Function passCallback) {}

void stopWebTiltDetection() {}
