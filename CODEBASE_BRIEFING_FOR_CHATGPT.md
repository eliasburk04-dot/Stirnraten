A) Quick Facts
- Stack: Flutter (Dart SDK >=3.0.0 <4.0.0), Provider, Google Fonts, flutter_staggered_grid_view, sensors_plus, audioplayers, shared_preferences, uuid.
- Rendering: Flutter UI (Skia) on mobile; Flutter Web build (client-rendered). No SSR/ISR.
- Deployment: Vercel (build/web) via `scripts/vercel_build.sh` and `vercel.json`.
- iOS approach: Native Flutter iOS runner in `ios/` (standard Flutter build, no Capacitor/React Native).
- Build commands: `flutter pub get`, `flutter run`, `flutter run -d chrome`, `flutter build web --release`, `flutter build ios` (or `flutter build ipa`).
- Node version: not specified / not required for Flutter build.
- Repo structure (top-level): `lib/`, `assets/`, `web/`, `ios/`, `android/`, `macos/`, `windows/`, `linux/`, `scripts/`, `test/`, `vercel.json`, `pubspec.yaml`.

B) Architektur Uebersicht (max. 30 Zeilen)
- Entry: `lib/main.dart` wires Providers (EffectsController, SoundService) and launches `HomeScreen`.
- State mgmt: Provider for global services; most screen state is local in StatefulWidgets.
- Game state machine: `lib/engine/stirnraten_engine.dart` holds GameSnapshot and rules (modes, timer, scoring).
- UI screens: `lib/screens/home_screen.dart` (landing), `lib/screens/stirnraten_screen.dart` (setup/game/results + custom words).
- Data: `lib/data/words.dart` provides category list, names, icons, and word lists.
- Persistence: `lib/services/custom_word_storage.dart` uses SharedPreferences for custom word lists.
- Audio/Haptics: `lib/services/sound_service.dart` (audioplayers + HapticFeedback).
- Sensors: `_TiltDetector` + `sensors_plus` in `stirnraten_screen.dart`; sensor permission helper stubs in `lib/utils/sensor_helper*.dart`.
- Visual system: glassmorphism in `lib/widgets/glass_widgets.dart` (BackdropFilter + gradients + shadows).
- Performance tuning: `lib/utils/effects_quality.dart` monitors frame timings and reduces blur/shadows.
- Web shell: `web/index.html`, `web/manifest.json`; Vercel rewrites all paths to `index.html`.

C) Screens & Routen
- HomeScreen (landing): `lib/screens/home_screen.dart` (start CTA -> Navigator push).
- StirnratenScreen (setup/countdown/play/result): `lib/screens/stirnraten_screen.dart`.
- CustomWordsScreen: `lib/screens/stirnraten_screen.dart` (embedded screen; opened via Navigator).
- CustomWordEditorScreen: `lib/screens/stirnraten_screen.dart` (embedded screen; opened from CustomWordsScreen).
- Routing: no named routes; `MaterialPageRoute` pushes from Home -> Stirnraten -> Custom screens.

D) Game Logic Map
- Core state: `StirnratenEngine` (GameSnapshot: state, mode, timeLeft, score, currentWord, remainingWords, results).
- Countdown start: `_startCountdownWithWords` in `stirnraten_screen.dart` -> `engine.startCountdown(words)`; locks orientation to landscape.
- Countdown tick: `_countdownTimer` (Timer.periodic) -> `engine.tickCountdown()`; when done calls `_startGame()`.
- Game start: `_startGame()` -> `engine.startGame()`, starts timer + sensors, resets feedback.
- Game timer: `_gameTimer` (Timer.periodic) -> `engine.tickTimer()`; ends game at 0.
- Sensor input: `_startSensors()` subscribes to `accelerometerEventStream()`; `_processSensorData()` throttles to 50ms and feeds `_TiltDetector` -> correct/pass.
- Actions: `_handleGameAction()` -> `engine.applyAction()`; mode-specific penalties for suddenDeath/hardcore/drinking.
- Word advance: `_nextWord()` -> `engine.advanceWord()`; ends when list is empty.
- End game: `_endGame()` -> `engine.endGame()` -> results UI.
- Categories: `StirnratenData.getWords(category)` from `lib/data/words.dart`.
- Custom words: `CustomWordStorage` (SharedPreferences) for create/edit/delete/play lists.
- Sound/haptics: `SoundService` methods in action handlers (start/correct/wrong/end).

E) Performance Suspects (Top 15)
| Rank | Datei | Abschnitt/Zeilen | Problem | Impact | Quick Fix Idee |
|---|---|---|---|---|---|
| 1 | lib/widgets/glass_widgets.dart | 21-27 | BackdropFilter blur in GlassBackdrop used across many widgets | High GPU cost, especially on mobile/web | Reduce blur radius, cache layers, or replace with pre-blurred assets for static cards |
| 2 | lib/widgets/glass_widgets.dart | 404-418 | Fullscreen GlassOverlay uses BackdropFilter blur | High when shown (full-screen blur) | Use solid overlay or lower blur; consider snapshot blur once |
| 3 | lib/screens/home_screen.dart | 45-56 | Multiple repeating AnimationControllers (bg + pulse) | Continuous rebuilds; energy drain | Pause when offscreen, reduce tick rate, or use `AnimatedBuilder` on smaller subtrees |
| 4 | lib/screens/home_screen.dart | 680-739 | Animated background stack with large glow layers | Large overdraw + heavy shadows | Flatten background into static image; reduce layers or sizes |
| 5 | lib/screens/home_screen.dart | 843-855 | _GlowOrb BoxShadow blur (very large radii) | Expensive rasterization | Reduce blur/spread or pre-render to PNG |
| 6 | lib/screens/stirnraten_screen.dart | 309-317 | Countdown Timer.periodic + setState every second | Rebuilds full screen each tick | Use ValueListenable/AnimatedBuilder to rebuild only timer HUD |
| 7 | lib/screens/stirnraten_screen.dart | 356-363 | Game Timer.periodic + setState every second | Same as above, during gameplay | Localize rebuilds; memoize widgets |
| 8 | lib/screens/stirnraten_screen.dart | 382-433 | Accelerometer stream + per-event math (50ms throttle) | CPU load; can contend with rendering | Move math to isolate; reduce sample rate; avoid debug logs |
| 9 | lib/screens/stirnraten_screen.dart | 1073-1095 | Fullscreen AnimatedOpacity overlay | Overdraw + alpha blending | Use `FadeTransition` on a cached child or reduce overlay size |
|10 | lib/screens/stirnraten_screen.dart | 1211-1224 | Results list container uses BackdropFilter blur | Large blur area | Remove blur or swap to translucent fill without blur |
|11 | lib/screens/stirnraten_screen.dart | 1358-1377 | HUD chips: BackdropFilter + shadow | Many chips on screen | Drop blur for HUD, keep simple solid pill |
|12 | lib/screens/stirnraten_screen.dart | 1752-1819 | CategoryCard: GlassBackdrop + AnimatedContainer + shadows | Many cards in grid -> heavy | Use static card style when not selected; reduce shadows |
|13 | lib/screens/stirnraten_screen.dart | 2271-2330 | Settings panel glass + shadow | Additional blur layer | Disable blur on low quality; use solid panel |
|14 | lib/screens/stirnraten_screen.dart | 2508-2517 | Sliver header BackdropFilter while scrolling | Blur during scroll | Remove blur on scroll or only apply when idle |
|15 | lib/screens/stirnraten_screen.dart | 3447-3497 | Category background glow orbs w/ huge blur | Heavy rasterization | Replace with static background image/gradient |

F) Assets & Styling
- Glassmorphism: centralized in `lib/widgets/glass_widgets.dart` (GlassBackdrop/GlassCard/GlassOverlay) using BackdropFilter + gradients + BoxShadow.
- Usage hotspots: `home_screen.dart` (top icon, start card), `stirnraten_screen.dart` (HUD chips, category cards, settings, custom lists, header).
- Fonts: GoogleFonts (Nunito, Fredoka, SpaceGrotesk) used throughout screens.
- Assets: `assets/images/stirnraten_image.png` (not referenced in code), sounds in `assets/sounds/*.wav` via SoundService.
- Global styles: `ThemeData.dark()` in `main.dart`, custom gradients in `ModernBackground` and screen-specific color constants.

G) Build/Deploy Pipeline
- Vercel: `vercel.json` runs `bash scripts/vercel_build.sh` -> `flutter build web --release` -> output `build/web`.
- Vercel headers: Permissions-Policy allows accelerometer/gyroscope for web sensors.
- Local build: `flutter build web` and `flutter test` (per README).
- iOS build: standard Flutter iOS build (`flutter build ios` or `flutter build ipa`), Xcode for signing.

H) Offene Fragen / Unklarheiten (max 5)
- Which target devices show the worst jank (iPhone model / browser + OS)?
- Is web running CanvasKit or HTML renderer in production (affects blur performance)?
