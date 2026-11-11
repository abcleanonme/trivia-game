# iPhone Duo checklist

Source: Apple's iPhone Duo tech talk and iOS 27.1 SDK notes. Re-check against
Apple's docs as APIs firm up.

## Requirements we follow
- Build with **Xcode 27.1 / iOS 27.1 SDK**. That SDK enables edge-to-edge
  content on the inner display and vertical toolbar/nav bar layouts.
- **Stay resizable.** Don't set `UIRequiresFullScreen`. The inner display
  ignores supported orientations for resizable apps.
- **Layout from size classes and local geometry only.** Never branch on
  `UIDevice.userInterfaceIdiom`, interface orientation, or `UIScreen.main`
  (ambiguous on two displays and being deprecated). Use
  `@Environment(\.displayScale)` instead of `UIScreen.main.scale`.
- The outer display behaves like a normal iPhone; the inner display is
  **regular x regular** (room for a sidebar).
- **Use system containers** (`TabView`, `NavigationStack/SplitView`, sheets,
  alerts) so bars move to vertical placement automatically. Standalone bars
  don't. Give toolbar items both a title and an SF Symbol.
- **Safe areas can be asymmetric.** Controls may sit on either side (Split
  View). Keep interactive content in the safe area and let backgrounds extend.
- **Same features in every pose.** Nothing may require opening or folding.

## Duo-specific APIs to adopt later
- `GeometryProxy.reservedRegion` / `ReservedRegion`: keep answer buttons and
  timers off the fold and away from the inner camera occlusion.
- `ArrangementView`: side-by-side layouts, e.g. question + live multiplayer
  scoreboard on the inner display. Don't nest navigation containers in it or
  put it inside a List/ScrollView.
- `onHingeChange`: optional fun (e.g. "tabletop" buzzer mode). Must degrade
  gracefully on devices without a hinge.
- `ToolbarOverflowMenu` for overflow actions; `visibilityPriority` on key items.
- Multiple scenes are supported, but new windows open only on the inner display;
  handle scene-request errors.

## Testing
Use Xcode 27.1 **Device Hub** with the iPhone Duo simulator: open, close,
rotate, half-fold, and Split View on both sides.
