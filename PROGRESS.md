# Progress Log

## Completed

- [x] Task-001: Xcode project setup (commit: c7b041b)
- [x] Task-002: Overlay Window — OverlayWindow, OverlayView, unit tests (commit: TBD)
- [x] Task-003: MaskRegion model and manager (commit: d76edcc)
- [x] Task-004: Window Tracker (commit: b879bdb)

---

## Current Iteration

- **Iteration:** 5
- **Working on:** Task-005 (next)
- **Started:** 2026-03-29

---

## Last Completed

- **Task-004:** Window Tracker
- **Tests:** 7/7 passing (WindowTrackerTests)
- **Key decisions:**
  - `CGWindowListProvider` protocol enables DI for unit tests (no real screen capture needed)
  - `SystemCGWindowListProvider` is the production impl; injects `MockCGWindowListProvider` in tests
  - `WindowTracker` polls at 30 FPS via `Timer`, skips regions with `nil` `targetWindowTitle`
  - `convertToAppKit` flips y-axis: `appKitY = screenHeight - cgY - height`

---

## Blockers

- None

---

## Notes

- Ralph loop initialized
- PRD created: 2026-03-29
- Source plan: PLAN.md (Multi-Area Real-Time Blur/Overlay Tool for macOS, Phase 1 MVP)
- 7 tasks defined; estimated 14–16 total iterations
