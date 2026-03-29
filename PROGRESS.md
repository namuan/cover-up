# Progress Log

## Completed

- [x] Task-001: Xcode project setup (commit: c7b041b)
- [x] Task-002: Overlay Window — OverlayWindow, OverlayView, unit tests (commit: TBD)
- [x] Task-003: MaskRegion model and manager (commit: d76edcc)
- [x] Task-004: Window Tracker (commit: b879bdb)
- [x] Task-006: HotkeyHandler, StatusMenuController, RegionListController (commit: 1f29ed8)
- [x] Task-006-fix: Add LSUIElement=true to Info.plist (commit: 50a4acf)
- [x] Task-007: Integration tests, performance test, component wiring (commit: d9ef5e6)
- [x] Task-007-fix: Real XCUITest with launch-arg control panel, test region pre-seeding (commit: 475bfd7)

---

## Current Iteration

- **Iteration:** 8
- **Working on:** DONE — all tasks complete
- **Started:** 2026-03-29

---

## Last Completed

- **Task-007:** Integration tests, performance test, component wiring verification
- **Tests:** 38/38 passing (+4 IntegrationTests)
- **Key decisions:**
  - `testPerformanceWith10Regions` uses explicit timing assertion (<5s for 90 ticks) instead of `measure {}` to avoid expectation re-use issues in repeated measure iterations
  - `MockCGWindowListProvider` reused from `WindowTrackerTests.swift` (same test target, no redefinition needed)
  - README updated with Screen Recording + Accessibility permission instructions
  - UITest target confirmed building successfully
- **Tests:** 34/34 passing (+6 HotkeyHandlerTests)
- **Key decisions:**
  - `HotkeyHandler.handleKeyEvent(flags:keyCode:)` is public for direct test invocation (no monitor needed in tests)
  - `HotkeyHandlerDelegate` protocol decouples dispatch from UI
  - `StatusMenuController` owns the status bar item and NSPanel control panel; stored strongly in AppDelegate
  - `RegionListController` uses NSStackView programmatically with Combine subscription for live updates
- **Tests:** 28/28 passing (+1 testUseBlurRegionNotDrawnAsBlack)
- **Key decisions:**
  - `OverlayView.draw()` now skips regions where `useBlur == true` (Phase 1: no blur implemented)
  - Removed duplicate "Last Completed" block from PROGRESS.md
  - Original Task-005 notes preserved below
- **Task-005:** Rendering Engine
- **Tests:** 27/27 passing (4 new OverlayViewTests added)
- **Key decisions:**
  - `OverlayView.draw()` clears to transparent then fills black for each active `MaskRegion.relativeRect`
  - `OverlayView.manager` injected via `didSet`; Combine subscription in `observeManager()` triggers `needsDisplay = true` on main thread
  - `OverlayWindow.convenience init(manager:)` injects manager into view after `configure()` runs; `override init` keeps old behaviour (ignores args, always uses screen-union frame) so ObjC/NSObject `init()` path still configures the window correctly
  - `OverlayView.needsDisplay` override adds `_markedForRedraw` backing flag: AppKit's display cycle can clear the system flag for detached views during `wait(for:timeout:)` in unit tests; backing flag survives until `draw()` is called
  - Off-screen rendering verified with `bitmapImageRepForCachingDisplay` + `cacheDisplay` — works headless
  - `AppDelegate` now wires `MaskRegionManager` → `OverlayWindow(manager:)` → `WindowTracker`; tracker's `onUpdate` calls `overlayView?.scheduleRedraw()`

---

## Blockers

- None

---

## Notes

- Ralph loop initialized
- PRD created: 2026-03-29
- Source plan: PLAN.md (Multi-Area Real-Time Blur/Overlay Tool for macOS, Phase 1 MVP)
- 7 tasks defined; estimated 14–16 total iterations
