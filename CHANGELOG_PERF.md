# Performance Changelog

- Reduced full-screen rebuilds by moving countdown/time updates to ValueNotifiers in `lib/screens/stirnraten_screen.dart`.
- Removed blur from HUD chips, category grid cards, results list, and custom list cards; kept glass look via translucent fills + borders.
- Lowered heavy glow/shadow blur radii in Home and Category backgrounds.
- Added effects quality hysteresis + minimum change interval to avoid rapid toggling.
- Throttled accelerometer processing and added app lifecycle pause/resume for sensor stream.
- Extracted large UI blocks into `lib/widgets/hud_timer.dart`, `lib/widgets/category_card.dart`, `lib/widgets/results_list.dart`, `lib/widgets/settings_panel.dart`.
- Added `docs/performance.md` with renderer notes and debug overlay flag.

## Expected Impact
- Fewer expensive repaints per second (timer + countdown only update their own widgets).
- Lower GPU load from reduced blur and shadow radii on glass surfaces.
- Lower CPU load from reduced sensor sampling rate.

## Visual Changes
- Glass blur removed from HUD and list/grid elements for performance.
- Background glow is slightly softer/less intense on low-end devices.
