import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:stirnraten/utils/tilt_controller.dart';

void main() {
  TiltController buildController() {
    return TiltController(
      neutralZoneDeg: 8,
      triggerDeg: 18,
      holdMs: 120,
      cooldownMs: 300,
      calibrationMs: 100,
      lowPassAlpha: 1.0,
    );
  }

  double zForDeg(double deg) => math.sin(deg * math.pi / 180);

  test('calibrates first and does not emit action during calibration', () {
    final controller = buildController()..start(0);

    final action0 = controller.update(
      x: 0,
      y: 1,
      z: 0,
      nowMs: 0,
      allowTrigger: true,
    );
    final action1 = controller.update(
      x: 0,
      y: 1,
      z: 0,
      nowMs: 60,
      allowTrigger: true,
    );
    final action2 = controller.update(
      x: 0,
      y: 1,
      z: 0,
      nowMs: 120,
      allowTrigger: true,
    );

    expect(action0, isNull);
    expect(action1, isNull);
    expect(action2, isNull);
    expect(controller.phase, TiltControllerPhase.active);
  });

  test('does not continuously retrigger without returning to neutral', () {
    final controller = buildController()..start(0);

    controller.update(x: 0, y: 1, z: 0, nowMs: 0, allowTrigger: true);
    controller.update(x: 0, y: 1, z: 0, nowMs: 120, allowTrigger: true);

    controller.update(x: 0, y: 1, z: 0, nowMs: 130, allowTrigger: true);

    controller.update(
      x: 0,
      y: 1,
      z: zForDeg(25),
      nowMs: 170,
      allowTrigger: true,
    );
    final first = controller.update(
      x: 0,
      y: 1,
      z: zForDeg(25),
      nowMs: 300,
      allowTrigger: true,
    );
    expect(first, TiltGestureAction.pass);

    final duringCooldown = controller.update(
      x: 0,
      y: 1,
      z: zForDeg(25),
      nowMs: 360,
      allowTrigger: true,
    );
    expect(duringCooldown, isNull);

    final afterCooldownStillTilted = controller.update(
      x: 0,
      y: 1,
      z: zForDeg(25),
      nowMs: 620,
      allowTrigger: true,
    );
    expect(afterCooldownStillTilted, isNull);

    controller.update(x: 0, y: 1, z: 0, nowMs: 700, allowTrigger: true);
    controller.update(
      x: 0,
      y: 1,
      z: zForDeg(25),
      nowMs: 730,
      allowTrigger: true,
    );
    final second = controller.update(
      x: 0,
      y: 1,
      z: zForDeg(25),
      nowMs: 870,
      allowTrigger: true,
    );
    expect(second, TiltGestureAction.pass);
  });

  test('negative tilt triggers correct action', () {
    final controller = buildController()..start(0);

    controller.update(x: 0, y: 1, z: 0, nowMs: 0, allowTrigger: true);
    controller.update(x: 0, y: 1, z: 0, nowMs: 120, allowTrigger: true);
    controller.update(x: 0, y: 1, z: 0, nowMs: 140, allowTrigger: true);

    controller.update(
      x: 0,
      y: 1,
      z: zForDeg(-25),
      nowMs: 210,
      allowTrigger: true,
    );
    final action = controller.update(
      x: 0,
      y: 1,
      z: zForDeg(-25),
      nowMs: 350,
      allowTrigger: true,
    );

    expect(action, TiltGestureAction.correct);
  });

  test('requires neutral after calibration before first trigger', () {
    final controller = buildController()..start(0);

    controller.update(x: 0, y: 1, z: 0, nowMs: 0, allowTrigger: true);
    controller.update(x: 0, y: 1, z: 0, nowMs: 120, allowTrigger: true);

    // Still tilted right after calibration should not immediately trigger.
    controller.update(
      x: 0,
      y: 1,
      z: zForDeg(24),
      nowMs: 180,
      allowTrigger: true,
    );
    final early = controller.update(
      x: 0,
      y: 1,
      z: zForDeg(24),
      nowMs: 340,
      allowTrigger: true,
    );
    expect(early, isNull);

    // After returning to neutral, trigger is allowed.
    controller.update(x: 0, y: 1, z: 0, nowMs: 380, allowTrigger: true);
    controller.update(
      x: 0,
      y: 1,
      z: zForDeg(24),
      nowMs: 430,
      allowTrigger: true,
    );
    final action = controller.update(
      x: 0,
      y: 1,
      z: zForDeg(24),
      nowMs: 560,
      allowTrigger: true,
    );
    expect(action, TiltGestureAction.pass);
  });

  test('hold time must be continuous and resets in dead zone', () {
    final controller = buildController()..start(0);

    controller.update(x: 0, y: 1, z: 0, nowMs: 0, allowTrigger: true);
    controller.update(x: 0, y: 1, z: 0, nowMs: 120, allowTrigger: true);
    controller.update(x: 0, y: 1, z: 0, nowMs: 130, allowTrigger: true);

    // First attempt: not long enough.
    controller.update(
      x: 0,
      y: 1,
      z: zForDeg(24),
      nowMs: 170,
      allowTrigger: true,
    );
    final tooSoon = controller.update(
      x: 0,
      y: 1,
      z: zForDeg(24),
      nowMs: 260,
      allowTrigger: true,
    );
    expect(tooSoon, isNull);

    // Return to near-neutral resets hold.
    controller.update(
      x: 0,
      y: 1,
      z: zForDeg(6),
      nowMs: 300,
      allowTrigger: true,
    );

    controller.update(
      x: 0,
      y: 1,
      z: zForDeg(24),
      nowMs: 340,
      allowTrigger: true,
    );
    final action = controller.update(
      x: 0,
      y: 1,
      z: zForDeg(24),
      nowMs: 470,
      allowTrigger: true,
    );
    expect(action, TiltGestureAction.pass);
  });

  test('invalid zero vector input is ignored and does not crash', () {
    final controller = buildController()..start(0);
    controller.update(x: 0, y: 1, z: 0, nowMs: 0, allowTrigger: true);
    controller.update(x: 0, y: 1, z: 0, nowMs: 120, allowTrigger: true);

    final action = controller.update(
      x: 0,
      y: 0,
      z: 0,
      nowMs: 200,
      allowTrigger: true,
    );

    expect(action, isNull);
    expect(controller.phase, TiltControllerPhase.active);
  });

  test('calibration baseline uses median and resists outliers', () {
    final controller = buildController()..start(0);

    controller.update(
      x: 0,
      y: 1,
      z: zForDeg(0),
      nowMs: 0,
      allowTrigger: true,
    );
    controller.update(
      x: 0,
      y: 1,
      z: zForDeg(1),
      nowMs: 30,
      allowTrigger: true,
    );
    controller.update(
      x: 0,
      y: 1,
      z: zForDeg(40), // Outlier
      nowMs: 60,
      allowTrigger: true,
    );
    controller.update(
      x: 0,
      y: 1,
      z: zForDeg(0),
      nowMs: 120,
      allowTrigger: true,
    );

    expect(controller.phase, TiltControllerPhase.active);
    expect(controller.baselineAngleDeg, closeTo(0.5, 0.6));
  });

  test(
      'allowTrigger=false does not produce action and should not consume gesture',
      () {
    final controller = buildController()..start(0);

    controller.update(x: 0, y: 1, z: 0, nowMs: 0, allowTrigger: true);
    controller.update(x: 0, y: 1, z: 0, nowMs: 120, allowTrigger: true);
    controller.update(x: 0, y: 1, z: 0, nowMs: 130, allowTrigger: true);

    // Gesture happens while blocked.
    controller.update(
      x: 0,
      y: 1,
      z: zForDeg(24),
      nowMs: 170,
      allowTrigger: false,
    );
    final blocked = controller.update(
      x: 0,
      y: 1,
      z: zForDeg(24),
      nowMs: 320,
      allowTrigger: false,
    );
    expect(blocked, isNull);

    // Once allowed again and still tilted, action should happen promptly.
    final allowedAgain = controller.update(
      x: 0,
      y: 1,
      z: zForDeg(24),
      nowMs: 450,
      allowTrigger: true,
    );
    expect(allowedAgain, TiltGestureAction.pass);
  });

  test(
      'stop resets state and blocks further actions until start is called again',
      () {
    final controller = buildController()..start(0);

    controller.update(x: 0, y: 1, z: 0, nowMs: 0, allowTrigger: true);
    controller.update(x: 0, y: 1, z: 0, nowMs: 120, allowTrigger: true);
    controller.stop();

    final action = controller.update(
      x: 0,
      y: 1,
      z: zForDeg(24),
      nowMs: 200,
      allowTrigger: true,
    );

    expect(action, isNull);
    expect(controller.phase, TiltControllerPhase.idle);
    expect(controller.lastDeltaDeg, 0.0);
    expect(controller.baselineAngleDeg, 0.0);
  });
}
