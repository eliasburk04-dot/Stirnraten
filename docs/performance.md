# Performance Notes (Stirnraten)

## Summary of Changes
- Timer + countdown UI now update via ValueNotifiers to avoid rebuilding the full game screen every second.
- Glassmorphism blur usage reduced and removed from scroll-heavy surfaces (HUD, category grid, results list, custom list cards).
- Background glow/shadow radii lowered to reduce GPU overdraw.
- Effects quality now uses hysteresis and cooldown to avoid rapid toggling.
- Sensor processing throttled to reduce CPU load, with lifecycle pause/resume handling.

## Debug Overlay (optional)
Enable Flutter's performance overlay in debug builds via:

```
flutter run --dart-define=SHOW_PERF_OVERLAY=true
```

This toggles `showPerformanceOverlay` in `lib/main.dart` only when `kDebugMode` is true.

## Web Renderer Note (CanvasKit vs HTML)
Flutter Web can render with CanvasKit or the HTML renderer. CanvasKit typically provides higher fidelity for blur/backdrop effects, but can be heavier on CPU/GPU and larger in download size. The HTML renderer can be lighter but often struggles with heavy blur/backdrop filters.

If you want to experiment, you can pass:
- `--web-renderer canvaskit`
- `--web-renderer html`

Example:
```
flutter build web --release --web-renderer canvaskit
```

## Suggested Profiling Flow
- iOS: `flutter run --profile`, use Flutter DevTools + iOS Instruments.
- Web: `flutter run -d chrome --profile`, use DevTools Performance tab.

## Repro Steps for Jank
1. Home -> Category screen -> Start game.
2. Play for 30-60s with sensor input.
3. Check frame times around timer ticks and during feedback overlay.
