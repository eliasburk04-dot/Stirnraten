/*
 * ============================================================================
 * TILT-SENSOR IMPLEMENTIERUNG FÜR IPHONE LERNKARTEN-APP
 * ============================================================================
 * 
 * ZWECK:
 * Diese Klasse implementiert eine Tilt-Steuerung für Lernkarten auf dem iPhone.
 * Der Benutzer hält das iPhone im QUERFORMAT und kann durch Neigen des Geräts
 * Aktionen auslösen:
 * - Nach VORNE neigen → Wort als RICHTIG markieren (Bildschirm GRÜN)
 * - Nach HINTEN neigen → Wort ÜBERSPRINGEN (Bildschirm ROT)
 * 
 * ============================================================================
 * TECHNISCHE DETAILS:
 * ============================================================================
 * 
 * SENSOR-ACHSEN (DeviceOrientation API):
 * - Alpha: Kompass-Richtung (0-360°) - NICHT VERWENDET
 * - Beta:  Rotation um X-Achse (vor/zurück im Hochformat) - Bereich: -180 bis 180°
 * - Gamma: Rotation um Y-Achse (links/rechts im Hochformat) - Bereich: -90 bis 90°
 * 
 * QUERFORMAT-SPEZIFISCH:
 * Wenn das iPhone im Querformat gehalten wird, ändern sich die Achsen:
 * - Beta liegt bei ~90° (Gerät liegt flach auf der Seite)
 * - Gamma wird zur Vor/Zurück-Neigung
 *   → Positiver Gamma-Wert = nach vorne geneigt (Oberseite des iPhones nach unten)
 *   → Negativer Gamma-Wert = nach hinten geneigt (Unterseite des iPhones nach unten)
 * 
 * ============================================================================
 * IOS-BERECHTIGUNGEN (WICHTIG!):
 * ============================================================================
 * 
 * Ab iOS 13+ benötigt DeviceOrientation eine explizite Berechtigung:
 * - DeviceOrientationEvent.requestPermission() muss aufgerufen werden
 * - MUSS durch eine User-Geste ausgelöst werden (z.B. Button-Klick)
 * - Funktioniert NUR über HTTPS (Vercel bietet dies automatisch)
 * 
 * INTEGRATION IN FLUTTER:
 * 1. Erstelle einen Button in deiner Flutter-UI
 * 2. Bei Klick: rufe JavaScript-Funktion auf, die controller.start() ausführt
 * 3. Verwende Platform-Channels oder JS-Interop für Callbacks
 * 
 * ============================================================================
 * STATE-MACHINE LOGIK:
 * ============================================================================
 * 
 * Der Controller verwendet eine State-Machine mit 3 Zuständen:
 * 
 * NEUTRAL → Wartet auf Neigung
 *   ↓
 *   Wenn tiltAngle > forwardThreshold (z.B. 25°)
 *   → Wechsel zu FORWARD → onTiltForward() wird aufgerufen
 *   
 *   Wenn tiltAngle < backwardThreshold (z.B. -25°)
 *   → Wechsel zu BACKWARD → onTiltBackward() wird aufgerufen
 * 
 * FORWARD/BACKWARD → Wartet auf Reset
 *   ↓
 *   Wenn |tiltAngle| < resetThreshold (z.B. 10°)
 *   → Zurück zu NEUTRAL → onReset() wird aufgerufen
 * 
 * VORTEIL: Verhindert mehrfaches Auslösen der gleichen Aktion.
 * Der Benutzer muss das Gerät erst zurück in neutrale Position bringen,
 * bevor die nächste Aktion erkannt wird.
 * 
 * ============================================================================
 * KONFIGURATION DER SCHWELLENWERTE:
 * ============================================================================
 * 
 * forwardThreshold: 25-35° empfohlen
 *   - Zu niedrig (< 20°): Zu empfindlich, versehentliches Auslösen
 *   - Zu hoch (> 40°): Unbequem, zu starke Neigung erforderlich
 * 
 * backwardThreshold: -25 bis -35° empfohlen
 *   - Sollte symmetrisch zu forwardThreshold sein
 * 
 * resetThreshold: 8-12° empfohlen
 *   - Sollte deutlich kleiner als forward/backward sein
 *   - Verhindert "Flattern" zwischen Zuständen
 * 
 * ============================================================================
 * VERWENDUNGSBEISPIEL IN FLUTTER WEB:
 * ============================================================================
 * 
 * // JavaScript-Seite (index.html oder separates .js file):
 * 
 * let tiltController;
 * 
 * function initTiltController() {
 *   tiltController = new TiltController({
 *     forwardThreshold: 30,
 *     backwardThreshold: -30,
 *     resetThreshold: 10,
 *     
 *     onTiltForward: () => {
 *       // Sende Event an Flutter
 *       window.postMessage({ type: 'TILT_FORWARD' }, '*');
 *       // Optional: Visuelles Feedback
 *       document.body.style.backgroundColor = '#00FF00';
 *     },
 *     
 *     onTiltBackward: () => {
 *       window.postMessage({ type: 'TILT_BACKWARD' }, '*');
 *       document.body.style.backgroundColor = '#FF0000';
 *     },
 *     
 *     onReset: () => {
 *       window.postMessage({ type: 'TILT_RESET' }, '*');
 *       document.body.style.backgroundColor = '#FFFFFF';
 *     }
 *   });
 * }
 * 
 * async function startTiltSensor() {
 *   try {
 *     await tiltController.start();
 *     console.log('✅ Tilt-Sensor aktiv');
 *     return true;
 *   } catch (error) {
 *     console.error('❌ Fehler beim Start:', error);
 *     return false;
 *   }
 * }
 * 
 * // Flutter-Seite (Dart):
 * 
 * import 'dart:html' as html;
 * import 'package:flutter/material.dart';
 * 
 * class LernkartenScreen extends StatefulWidget {
 *   @override
 *   _LernkartenScreenState createState() => _LernkartenScreenState();
 * }
 * 
 * class _LernkartenScreenState extends State<LernkartenScreen> {
 *   Color backgroundColor = Colors.white;
 * 
 *   @override
 *   void initState() {
 *     super.initState();
 *     
 *     // Höre auf JavaScript-Messages
 *     html.window.addEventListener('message', (event) {
 *       final data = (event as html.MessageEvent).data;
 *       
 *       if (data['type'] == 'TILT_FORWARD') {
 *         setState(() {
 *           backgroundColor = Colors.green;
 *           // Hier: Karte als richtig markieren
 *           markCardAsCorrect();
 *         });
 *       } else if (data['type'] == 'TILT_BACKWARD') {
 *         setState(() {
 *           backgroundColor = Colors.red;
 *           // Hier: Karte überspringen
 *           skipCard();
 *         });
 *       } else if (data['type'] == 'TILT_RESET') {
 *         setState(() {
 *           backgroundColor = Colors.white;
 *         });
 *       }
 *     });
 *   }
 * 
 *   Future<void> _enableTiltSensor() async {
 *     // Rufe JavaScript-Funktion auf
 *     final result = await html.window.callMethod('startTiltSensor');
 *     
 *     if (result == true) {
 *       ScaffoldMessenger.of(context).showSnackBar(
 *         SnackBar(content: Text('Tilt-Sensor aktiviert!')),
 *       );
 *     } else {
 *       ScaffoldMessenger.of(context).showSnackBar(
 *         SnackBar(content: Text('Berechtigung verweigert')),
 *       );
 *     }
 *   }
 * 
 *   @override
 *   Widget build(BuildContext context) {
 *     return Scaffold(
 *       backgroundColor: backgroundColor,
 *       body: Center(
 *         child: Column(
 *           mainAxisAlignment: MainAxisAlignment.center,
 *           children: [
 *             ElevatedButton(
 *               onPressed: _enableTiltSensor,
 *               child: Text('Tilt-Steuerung aktivieren'),
 *             ),
 *             // Deine Lernkarten-UI hier
 *           ],
 *         ),
 *       ),
 *     );
 *   }
 * }
 * 
 * ============================================================================
 * DEBUGGING TIPPS:
 * ============================================================================
 * 
 * 1. Console-Logs: Die Klasse loggt alle State-Änderungen
 * 2. Teste im echten iPhone (nicht Simulator!)
 * 3. Überprüfe HTTPS-Verbindung (erforderlich für DeviceOrientation)
 * 4. Stelle sicher, dass Berechtigung durch Button-Klick angefordert wird
 * 5. Teste verschiedene Schwellenwerte für deine Präferenz
 * 
 * HÄUFIGE FEHLER:
 * - "DeviceOrientation not supported": Teste auf echtem iPhone
 * - Permission denied: Berechtigung muss durch User-Geste erfolgen
 * - Keine Events: Überprüfe HTTPS und iOS-Version (13+)
 * - Falsche Richtung: Stelle sicher, dass Querformat erkannt wird
 * 
 * ============================================================================
 */

class TiltController {
  constructor(options = {}) {
    this.onTiltForward = options.onTiltForward || (() => {});
    this.onTiltBackward = options.onTiltBackward || (() => {});
    this.onReset = options.onReset || (() => {});
    this.onOrientation = options.onOrientation || (() => {});
    
    // Schwellenwerte für Neigung (in Grad)
    this.forwardThreshold = options.forwardThreshold || 25;
    this.backwardThreshold = options.backwardThreshold || -25;
    this.resetThreshold = options.resetThreshold || 10; // Zurück zu neutral
    
    this.currentState = 'neutral'; // 'neutral', 'forward', 'backward'
    this.isActive = false;
    this._boundHandleOrientation = this.handleOrientation.bind(this);
  }
  
  // Starte die Sensor-Überwachung
  async start(options = {}) {
    const shouldRequestPermission = options.requestPermission !== false;
    if (typeof DeviceOrientationEvent === 'undefined') {
      throw new Error('DeviceOrientation wird nicht unterstützt');
    }
    
    // iOS 13+ benötigt Berechtigung
    if (shouldRequestPermission && typeof DeviceOrientationEvent.requestPermission === 'function') {
      try {
        const permission = await DeviceOrientationEvent.requestPermission();
        if (permission !== 'granted') {
          throw new Error('Berechtigung für Bewegungssensor wurde verweigert');
        }
      } catch (error) {
        throw new Error('Fehler bei Berechtigungsanfrage: ' + error.message);
      }
    }
    
    this.isActive = true;
    window.addEventListener('deviceorientation', this._boundHandleOrientation);
    console.log('Tilt-Controller gestartet');
  }
  
  // Stoppe die Sensor-Überwachung
  stop() {
    this.isActive = false;
    window.removeEventListener('deviceorientation', this._boundHandleOrientation);
    console.log('Tilt-Controller gestoppt');
  }
  
  // Verarbeite Orientierungsdaten
  handleOrientation(event) {
    if (!this.isActive) return;
    
    // Beta: Rotation um X-Achse (Vor/Zurück-Neigung)
    // Positiv = nach vorne geneigt, Negativ = nach hinten geneigt
    const beta = event.beta;
    
    // Gamma: Rotation um Y-Achse (Links/Rechts-Neigung)
    const gamma = event.gamma;
    
    // Alpha: Kompass-Ausrichtung (wird hier nicht benötigt)
    // const alpha = event.alpha;
    
    if (beta === null || gamma === null) return;
    this.onOrientation(event);
    
    // Korrektur für Querformat: 
    // Im Querformat ist die Interpretation anders
    // Wir nutzen gamma für die Vor/Zurück-Neigung im Querformat
    let tiltAngle;
    
    // Erkenne Querformat anhand von beta
    if (Math.abs(beta) > 45) {
      // Querformat (Landscape)
      // gamma wird zur Vor/Zurück-Neigung
      tiltAngle = gamma;
    } else {
      // Hochformat (Portrait) - sollte nicht verwendet werden
      tiltAngle = beta;
    }
    
    // State-Machine für saubere Übergänge
    if (this.currentState === 'neutral') {
      if (tiltAngle > this.forwardThreshold) {
        this.currentState = 'forward';
        this.onTiltForward();
        console.log('Tilted FORWARD:', tiltAngle);
      } else if (tiltAngle < this.backwardThreshold) {
        this.currentState = 'backward';
        this.onTiltBackward();
        console.log('Tilted BACKWARD:', tiltAngle);
      }
    } else {
      // Zurück zu neutral, wenn Neigung unter Schwellenwert
      if (Math.abs(tiltAngle) < this.resetThreshold) {
        this.currentState = 'neutral';
        this.onReset();
        console.log('Reset to NEUTRAL:', tiltAngle);
      }
    }
  }
  
  // Aktuelle Neigung abfragen (für Debugging)
  getCurrentOrientation() {
    return this.currentState;
  }
}

// Beispiel-Verwendung:
/*
const tiltController = new TiltController({
  forwardThreshold: 30,    // Grad für "nach vorne"
  backwardThreshold: -30,  // Grad für "nach hinten"
  resetThreshold: 10,      // Zurück zu neutral
  
  onTiltForward: () => {
    // Hier: Wort als richtig markieren, Bildschirm grün
    console.log('✅ RICHTIG');
  },
  
  onTiltBackward: () => {
    // Hier: Wort überspringen, Bildschirm rot
    console.log('❌ ÜBERSPRINGEN');
  },
  
  onReset: () => {
    // Zurück zu neutralem Zustand
    console.log('⚪ NEUTRAL');
  }
});

// Starten (mit Button-Klick wegen iOS-Berechtigung)
document.getElementById('startBtn').addEventListener('click', async () => {
  try {
    await tiltController.start();
    console.log('Bereit für Tilt-Steuerung!');
  } catch (error) {
    console.error('Fehler beim Starten:', error);
  }
});

// Optional: Stoppen
// tiltController.stop();
*/

// Export für Module
if (typeof module !== 'undefined' && module.exports) {
  module.exports = TiltController;
}

(function () {
  if (typeof window === 'undefined') return;

  if (!window.latestAccelerometerData) {
    window.latestAccelerometerData = { x: 0, y: 0, z: 0 };
  }
  if (typeof window.sensorAvailable !== 'boolean') {
    window.sensorAvailable = false;
  }

  function updateLatest(event) {
    if (!event) return;
    const beta = event.beta;
    const gamma = event.gamma;
    const alpha = event.alpha;
    if (beta == null && gamma == null && alpha == null) return;
    window.sensorAvailable = true;
    window.latestAccelerometerData.x = beta ?? 0;
    window.latestAccelerometerData.y = gamma ?? 0;
    window.latestAccelerometerData.z = alpha ?? 0;
  }

  window.requestDeviceMotionPermission = async function () {
    if (typeof DeviceOrientationEvent === 'undefined') {
      return false;
    }
    if (typeof DeviceOrientationEvent.requestPermission === 'function') {
      try {
        const result = await DeviceOrientationEvent.requestPermission();
        return result === 'granted';
      } catch (error) {
        console.warn('requestDeviceMotionPermission failed', error);
        return false;
      }
    }
    return true;
  };

  let controller = null;

  window.tiltDetection = {
    start: function (correctCallback, passCallback) {
      window.sensorAvailable = false;
      if (controller) {
        controller.stop();
      }
      controller = new TiltController({
        onTiltForward:
          typeof correctCallback === 'function' ? correctCallback : () => {},
        onTiltBackward:
          typeof passCallback === 'function' ? passCallback : () => {},
        onReset: () => {},
        onOrientation: updateLatest,
      });
      controller
        .start({ requestPermission: false })
        .catch((error) =>
          console.warn('Failed to start tilt detection', error),
        );
    },
    stop: function () {
      if (!controller) return;
      controller.stop();
      controller = null;
    },
  };
})();
