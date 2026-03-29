# Progress Log

## Completed

- [x] Task-001: Xcode project setup (commit: c7b041b)
- [x] Task-002: Overlay Window — OverlayWindow, OverlayView, unit tests (commit: TBD)
- [x] Task-003: MaskRegion model and manager (commit: d76edcc)
- [x] Task-004: Window Tracker (commit: b879bdb)
- [x] Task-005: Rendering Engine — OverlayView draws regions, wired with MaskRegionManager, off-screen tests (commit: TBD)

---

## Current Iteration

- **Iteration:** 6
- **Working on:** Task-006 (next)
- **Started:** 2026-03-29

---

## Last Completed

- **Task-005-fix:** useBlur guard + test
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
