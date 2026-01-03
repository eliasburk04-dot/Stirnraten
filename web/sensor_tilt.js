// Tilt Detection System for Stirnraten Game
// This file handles all accelerometer/gyroscope input for the web version

window.tiltDetection = {
  isActive: false,
  neutralPosition: true,
  lastTilt: 0,
  cooldownMs: 0,  // No cooldown
  tiltThreshold: 3.0,  // Low threshold for reliable detection
  neutralThreshold: 1.5,  // Low neutral threshold
  correctCallback: null,
  passCallback: null,
  debugMode: true,
  lastX: 0,
  lastY: 0,
  lastZ: 0,
  
  start: function(correctCallback, passCallback) {
    this.isActive = true;
    this.neutralPosition = true;
    this.correctCallback = correctCallback;
    this.passCallback = passCallback;
    this.lastTilt = 0;
    console.log('🎮 Tilt detection started v4 - callbacks registered:', !!correctCallback, !!passCallback);
  },
  
  stop: function() {
    this.isActive = false;
    this.correctCallback = null;
    this.passCallback = null;
    console.log('🎮 Tilt detection stopped');
  },
  
  processTilt: function(x, y, z) {
    if (!this.isActive) return;
    
    // Store latest values
    this.lastX = x;
    this.lastY = y;
    this.lastZ = z;
    
    const now = Date.now();
    
    // For Stirnraten: Phone is held at forehead in LANDSCAPE mode
    // The phone's screen faces away from the user
    // 
    // When tilting FORWARD (showing word to others): 
    //   - On Android: Y becomes more positive
    //   - On iOS: Y becomes more negative (inverted)
    //
    // When tilting BACKWARD (hiding word):
    //   - On Android: Y becomes more negative  
    //   - On iOS: Y becomes more positive (inverted)
    //
    // We use Y-axis primarily as it's most reliable in landscape
    
    // Detect if iOS (accelerometer is inverted on iOS)
    const isIOS = /iPad|iPhone|iPod/.test(navigator.userAgent);
    
    // Use Y-axis for landscape tilt detection
    // Invert for iOS
    let tiltValue = isIOS ? -y : y;
    
    // Alternative: Try using the axis with the largest absolute change
    // This makes it more robust across different phone orientations
    const absX = Math.abs(x);
    const absY = Math.abs(y);
    
    // If X has stronger signal than Y, use X (might be in different orientation)
    if (absX > absY + 2) {
      tiltValue = isIOS ? -x : x;
    }
    
    // Debug logging (every 200ms to reduce spam but see more)
    if (this.debugMode && now % 200 < 25) {
      console.log(`🌐 x=${x.toFixed(1)}, y=${y.toFixed(1)}, z=${z.toFixed(1)} | tilt=${tiltValue.toFixed(1)} | iOS=${isIOS} | neutral=${this.neutralPosition}`);
    }
    
    // Neutral Position detection - must return to neutral before next action
    if (Math.abs(tiltValue) < this.neutralThreshold) {
      if (!this.neutralPosition) {
        console.log('✅ Neutral restored');
      }
      this.neutralPosition = true;
      return;
    }
    
    // Only trigger if coming from neutral position
    if (!this.neutralPosition) return;
    
    // Forward tilt = CORRECT (show word to others)
    if (tiltValue > this.tiltThreshold) {
      console.log('🟢 CORRECT! tilt=' + tiltValue.toFixed(1));
      this.neutralPosition = false;
      this.lastTilt = now;
      this.triggerCorrect();
    }
    // Backward tilt = PASS (hide word)
    else if (tiltValue < -this.tiltThreshold) {
      console.log('🔴 PASS! tilt=' + tiltValue.toFixed(1));
      this.neutralPosition = false;
      this.lastTilt = now;
      this.triggerPass();
    }
  },
  
  triggerCorrect: function() {
    if (this.correctCallback && typeof this.correctCallback === 'function') {
      try {
        this.correctCallback();
      } catch (e) {
        console.error('❌ Correct callback error:', e);
      }
    }
  },
  
  triggerPass: function() {
    if (this.passCallback && typeof this.passCallback === 'function') {
      try {
        this.passCallback();
      } catch (e) {
        console.error('❌ Pass callback error:', e);
      }
    }
  },
  
  // Manual trigger functions for testing or touch fallback
  forceCorrect: function() {
    if (this.isActive) {
      console.log('🟢 Force CORRECT triggered');
      this.triggerCorrect();
    }
  },
  
  forcePass: function() {
    if (this.isActive) {
      console.log('🔴 Force PASS triggered');
      this.triggerPass();
    }
  }
};

// Global variable to store latest acceleration including gravity
window.latestAccelerometerData = { x: 0, y: 0, z: 0 };
window.sensorInitialized = false;
window.sensorAvailable = false;

// Initialize device motion listener
function initDeviceMotion() {
  if (window.sensorInitialized) {
    console.log('📱 Sensor already initialized');
    return;
  }
  
  window.addEventListener('devicemotion', (event) => {
    if (event.accelerationIncludingGravity) {
      const x = event.accelerationIncludingGravity.x || 0;
      const y = event.accelerationIncludingGravity.y || 0;
      const z = event.accelerationIncludingGravity.z || 0;
      
      // Mark sensor as available if we get non-zero values
      if (x !== 0 || y !== 0 || z !== 0) {
        window.sensorAvailable = true;
      }
      
      window.latestAccelerometerData = { x, y, z };
      window.tiltDetection.processTilt(x, y, z);
    }
  }, true);
  
  window.sensorInitialized = true;
  console.log('📱 Device motion listener initialized');
}

// Helper to request DeviceMotion permission on iOS 13+
window.requestDeviceMotionPermission = function() {
  console.log('📱 Requesting device motion permission...');
  
  if (typeof DeviceMotionEvent !== 'undefined' && typeof DeviceMotionEvent.requestPermission === 'function') {
    // iOS 13+ requires permission request
    console.log('📱 iOS 13+ detected, requesting permission...');
    return DeviceMotionEvent.requestPermission()
      .then(permissionState => {
        console.log('📱 Permission state:', permissionState);
        if (permissionState === 'granted') {
          initDeviceMotion();
          return true;
        }
        return false;
      })
      .catch(error => {
        console.error('❌ Permission request error:', error);
        return false;
      });
  } else {
    // Non-iOS 13+ devices (Android, older iOS) - no permission needed
    console.log('📱 Non-iOS device, initializing directly...');
    initDeviceMotion();
    return Promise.resolve(true);
  }
};

// Check if sensors are working
window.checkSensorStatus = function() {
  return {
    initialized: window.sensorInitialized,
    available: window.sensorAvailable,
    lastData: window.latestAccelerometerData,
    tiltActive: window.tiltDetection.isActive
  };
};

// Auto-initialize for non-iOS devices
if (typeof DeviceMotionEvent === 'undefined' || typeof DeviceMotionEvent.requestPermission !== 'function') {
  console.log('📱 Auto-initializing sensor for non-iOS device...');
  if (document.readyState === 'complete') {
    initDeviceMotion();
  } else {
    window.addEventListener('load', initDeviceMotion);
  }
}

console.log('✅ sensor_tilt.js loaded successfully v2');
