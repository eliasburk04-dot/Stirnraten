Future<bool> requestSensorPermission() async => true;

List<double> getWebAccelerometerData() => [0.0, 0.0, 0.0];

bool getWebSensorAvailable() => false;

void startWebTiltDetection(Function correctCallback, Function passCallback) {}

void stopWebTiltDetection() {}
