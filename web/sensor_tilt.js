(() => {
  const config = {
    deadzone: 12,
    trigger: 30,
    cooldownMs: 1000,
    sampleMs: 40,
    smoothingSamples: 6,
    calibrationSamples: 10,
  };

  let enabled = false;
  let permissionGranted = false;
  const permissionRequired =
    typeof DeviceOrientationEvent !== 'undefined' &&
    typeof DeviceOrientationEvent.requestPermission === 'function';

  let onCorrect = null;
  let onSkip = null;
  let lastSampleTs = 0;
  let lastTriggerTs = 0;
  let armed = true;
  let offset = 0;
  let hasOffset = false;
  let calibration = [];
  let samples = [];
  let usingMotion = false;

  window.latestAccelerometerData = { x: 0, y: 0, z: 0 };
  window.sensorAvailable = false;

  const STORAGE_KEY = 'tiltOffsetV1';

  function loadOffset() {
    try {
      const raw = localStorage.getItem(STORAGE_KEY);
      if (!raw) return;
      const parsed = JSON.parse(raw);
      if (!parsed || typeof parsed.value !== 'number') return;
      const ageMs = Date.now() - (parsed.time || 0);
      if (ageMs > 12 * 60 * 60 * 1000) return;
      if (Math.abs(parsed.value) > 45) return;
      offset = parsed.value;
      hasOffset = true;
    } catch (_) {}
  }

  function saveOffset(value) {
    try {
      localStorage.setItem(
        STORAGE_KEY,
        JSON.stringify({ value, time: Date.now() })
      );
    } catch (_) {}
  }

  function resetCalibration() {
    offset = 0;
    hasOffset = false;
    calibration = [];
    samples = [];
    loadOffset();
  }

  function getOrientationAngle() {
    if (screen.orientation && typeof screen.orientation.angle === 'number') {
      return screen.orientation.angle;
    }
    const w = window.orientation;
    if (typeof w === 'number') return w;
    return 0;
  }

  function mapForward(beta, gamma, angle) {
    // iOS Safari (landscape): forward/back aligns with gamma, angle decides sign.
    switch (angle) {
      case 90:
        return -gamma;
      case -90:
      case 270:
        return gamma;
      case 180:
        return -beta;
      case 0:
      default:
        return beta;
    }
  }

  function smoothValue(value) {
    samples.push(value);
    if (samples.length > config.smoothingSamples) {
      samples.shift();
    }
    const sum = samples.reduce((acc, v) => acc + v, 0);
    return sum / samples.length;
  }

  function calibrate(value) {
    if (hasOffset) return;
    calibration.push(value);
    if (calibration.length < config.calibrationSamples) return;
    const sum = calibration.reduce((acc, v) => acc + v, 0);
    offset = sum / calibration.length;
    hasOffset = true;
    saveOffset(offset);
  }

  function handleValue(raw, now) {
    calibrate(raw);
    const adjusted = raw - offset;
    const smoothed = smoothValue(adjusted);

    if (Math.abs(smoothed) <= config.deadzone) {
      armed = true;
      return;
    }

    if (!armed) return;
    if (now - lastTriggerTs < config.cooldownMs) return;

    if (smoothed >= config.trigger) {
      lastTriggerTs = now;
      armed = false;
      if (onCorrect) onCorrect();
      return;
    }

    if (smoothed <= -config.trigger) {
      lastTriggerTs = now;
      armed = false;
      if (onSkip) onSkip();
    }
  }

  function handleOrientation(event) {
    if (!enabled) return;
    if (typeof event.beta !== 'number' || typeof event.gamma !== 'number') return;

    const now = performance.now();
    if (now - lastSampleTs < config.sampleMs) return;
    lastSampleTs = now;

    window.sensorAvailable = true;

    const beta = event.beta;
    const gamma = event.gamma;
    const angle = getOrientationAngle();
    const forward = mapForward(beta, gamma, angle);
    handleValue(forward, now);
  }

  function handleMotion(event) {
    if (!enabled || !event.accelerationIncludingGravity) return;
    const now = performance.now();
    if (now - lastSampleTs < config.sampleMs) return;
    lastSampleTs = now;

    const acc = event.accelerationIncludingGravity;
    const x = acc.x || 0;
    const y = acc.y || 0;
    const z = acc.z || 0;

    window.latestAccelerometerData = { x, y, z };
    window.sensorAvailable = true;

    const norm = Math.sqrt(x * x + y * y + z * z);
    if (!norm) return;

    const ny = y / norm;
    const nz = z / norm;
    const beta = Math.atan2(ny, nz) * (180 / Math.PI);
    const angle = getOrientationAngle();
    const forward = mapForward(beta, 0, angle);
    handleValue(forward, now);
  }

  function startListeners() {
    if (usingMotion) {
      window.addEventListener('devicemotion', handleMotion, { passive: true });
    } else {
      window.addEventListener('deviceorientation', handleOrientation, { passive: true });
    }
  }

  function stopListeners() {
    window.removeEventListener('deviceorientation', handleOrientation);
    window.removeEventListener('devicemotion', handleMotion);
  }

  async function requestDeviceMotionPermission() {
    if (!permissionRequired) {
      permissionGranted = true;
      return true;
    }
    try {
      const result = await DeviceOrientationEvent.requestPermission();
      permissionGranted = result === 'granted';
      return permissionGranted;
    } catch (_) {
      permissionGranted = false;
      return false;
    }
  }

  function start(correctCallback, skipCallback) {
    onCorrect = typeof correctCallback === 'function' ? correctCallback : null;
    onSkip = typeof skipCallback === 'function' ? skipCallback : null;
    enabled = true;
    resetCalibration();
    window.sensorAvailable = false;

    usingMotion =
      typeof DeviceOrientationEvent === 'undefined' &&
      typeof DeviceMotionEvent !== 'undefined';

    if (!permissionRequired) {
      permissionGranted = true;
    }

    if (permissionGranted) {
      stopListeners();
      startListeners();
    }
  }

  function stop() {
    enabled = false;
    onCorrect = null;
    onSkip = null;
    stopListeners();
  }

  window.requestDeviceMotionPermission = requestDeviceMotionPermission;
  window.isTiltPermissionRequired = () => permissionRequired;
  window.tiltDetection = {
    start,
    stop,
  };
})();
