(() => {
  const state = {
    enabled: false,
    correctCallback: null,
    passCallback: null,
    lastSampleMs: 0,
    lastTriggerMs: 0,
    cooldownMs: 1000,
    deadzone: 12,
    threshold: 30,
    armed: true,
    smoothWindow: 6,
    samples: [],
    offset: 0,
    calibrating: false,
    calibrationStart: 0,
    calibrationDuration: 500,
    sensorAvailable: false,
    useOrientation: true,
  };

  window.latestAccelerometerData = { x: 0, y: 0, z: 0 };
  window.sensorAvailable = false;

  const nowMs = () => (performance && performance.now ? performance.now() : Date.now());

  const getOrientationAngle = () => {
    if (screen.orientation && typeof screen.orientation.angle === 'number') {
      return screen.orientation.angle;
    }
    if (typeof window.orientation === 'number') {
      return window.orientation;
    }
    return 0;
  };

  // iPhone Safari in landscape: gamma represents forward/back, but sign flips with angle.
  const computeTiltForward = (beta, gamma) => {
    const angle = getOrientationAngle();
    if (angle === 90) {
      return -gamma;
    }
    if (angle === -90 || angle === 270) {
      return gamma;
    }
    if (angle === 180) {
      return -beta;
    }
    return beta;
  };

  const smoothValue = (value) => {
    state.samples.push(value);
    if (state.samples.length > state.smoothWindow) {
      state.samples.shift();
    }
    const sum = state.samples.reduce((acc, v) => acc + v, 0);
    return sum / state.samples.length;
  };

  const processTilt = (rawValue) => {
    const now = nowMs();
    if (now - state.lastSampleMs < 33) {
      return;
    }
    state.lastSampleMs = now;

    if (state.calibrating) {
      state.samples.push(rawValue);
      if (now - state.calibrationStart >= state.calibrationDuration || state.samples.length >= 12) {
        const sum = state.samples.reduce((acc, v) => acc + v, 0);
        state.offset = sum / state.samples.length;
        state.samples = [];
        state.calibrating = false;
      }
      return;
    }

    const adjusted = rawValue - state.offset;
    const smoothed = smoothValue(adjusted);

    if (Math.abs(smoothed) <= state.deadzone) {
      state.armed = true;
      return;
    }

    if (!state.armed) {
      return;
    }

    if (now - state.lastTriggerMs < state.cooldownMs) {
      return;
    }

    if (smoothed >= state.threshold) {
      state.lastTriggerMs = now;
      state.armed = false;
      if (state.correctCallback) {
        state.correctCallback();
      }
      return;
    }

    if (smoothed <= -state.threshold) {
      state.lastTriggerMs = now;
      state.armed = false;
      if (state.passCallback) {
        state.passCallback();
      }
    }
  };

  const handleOrientation = (event) => {
    if (!state.enabled) return;
    if (event.beta == null || event.gamma == null) {
      state.useOrientation = false;
      return;
    }
    window.sensorAvailable = true;
    state.sensorAvailable = true;
    const tilt = computeTiltForward(event.beta, event.gamma);
    processTilt(tilt);
  };

  const handleMotion = (event) => {
    if (!state.enabled) return;
    const acc = event.accelerationIncludingGravity;
    if (!acc) return;
    const x = acc.x || 0;
    const y = acc.y || 0;
    const z = acc.z || 0;
    window.latestAccelerometerData = { x, y, z };
    window.sensorAvailable = true;
    state.sensorAvailable = true;
    if (state.useOrientation) return;
    const angle = getOrientationAngle();
    let forward = 0;
    const norm = Math.sqrt(x * x + y * y + z * z) || 1;
    const ny = y / norm;
    const nz = z / norm;
    let pitch = Math.atan2(ny, nz) * (180 / Math.PI);
    if (angle === 90) {
      forward = -pitch;
    } else if (angle === -90 || angle === 270) {
      forward = pitch;
    } else if (angle === 180) {
      forward = -pitch;
    } else {
      forward = pitch;
    }
    processTilt(forward);
  };

  window.isTiltPermissionRequired = () => {
    return typeof DeviceOrientationEvent !== 'undefined' &&
      typeof DeviceOrientationEvent.requestPermission === 'function';
  };

  window.requestDeviceMotionPermission = async () => {
    if (!window.isTiltPermissionRequired()) {
      return true;
    }
    try {
      const result = await DeviceOrientationEvent.requestPermission();
      return result === 'granted';
    } catch (_) {
      return false;
    }
  };

  window.tiltDetection = {
    start: (correctCallback, passCallback) => {
      if (state.enabled) return;
      state.enabled = true;
      state.correctCallback = correctCallback;
      state.passCallback = passCallback;
      state.lastTriggerMs = 0;
      state.lastSampleMs = 0;
      state.armed = true;
      state.useOrientation = true;
      state.calibrating = true;
      state.calibrationStart = nowMs();
      state.samples = [];
      window.addEventListener('deviceorientation', handleOrientation, { passive: true });
      window.addEventListener('devicemotion', handleMotion, { passive: true });
    },
    stop: () => {
      if (!state.enabled) return;
      state.enabled = false;
      state.correctCallback = null;
      state.passCallback = null;
      window.removeEventListener('deviceorientation', handleOrientation);
      window.removeEventListener('devicemotion', handleMotion);
    },
  };
})();
