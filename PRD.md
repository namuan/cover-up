# Feature: Multi-Area Real-Time Blur/Overlay Tool for macOS (Phase 1 MVP)

## Overview

A macOS application that hides multiple sensitive screen regions in real-time using always-on-top,
click-through black-box overlays. Regions can track moving windows by title or sit at static
coordinates. Phase 1 focuses on functionality: black-box masking, window tracking, and basic region
management via hotkeys. No post-processing or video editing required.

**Stack:** Swift · AppKit · Core Graphics · CGWindow API · XCTest/XCUITest

---

## Success Criteria

- [ ] All tasks complete
- [ ] All tests passing (`xcodebuild test`)
- [ ] Build succeeds (`xcodebuild build`)
- [ ] Overlay renders at ≥30 FPS with at least 2 tracked windows
- [ ] Screen recording captures masked areas correctly

---

## Tasks

### Task-001: Xcode Project Setup

**Priority:** High
**Estimated Iterations:** 1

**Acceptance Criteria:**

- [ ] macOS App target created (AppKit, Swift, minimum deployment macOS 12)
- [ ] Folder structure: `Sources/CoverUp/`, `Tests/CoverUpTests/`, `Tests/CoverUpUITests/`
- [ ] `com.apple.security.screen-recording` entitlement declared in `.entitlements` file
- [ ] `NSScreenCaptureUsageDescription` key present in `Info.plist`
- [ ] Project builds without errors or warnings
- [ ] `README.md` with build/run instructions committed

**Verification:**

```bash
xcodebuild -scheme CoverUp -destination 'platform=macOS' build
```

---

### Task-002: Overlay Window

**Priority:** High
**Estimated Iterations:** 2

Create a single transparent NSWindow that covers all connected screens and renders all mask regions.

**Acceptance Criteria:**

- [ ] `OverlayWindow` subclass of `NSWindow` created
- [ ] Window style: borderless (`NSWindow.StyleMask.borderless`)
- [ ] Window level: `NSWindow.Level.screenSaver` (floats above all apps)
- [ ] Background: fully transparent (`backgroundColor = .clear`, `isOpaque = false`)
- [ ] Click-through: `ignoresMouseEvents = true`
- [ ] Window frame spans all connected screens (union of all `NSScreen.screens` frames)
- [ ] `OverlayView` (NSView subclass) hosted inside `OverlayWindow` as content view
- [ ] `OverlayWindow` can be shown/hidden programmatically
- [ ] Unit test: verify window level, transparency, and `ignoresMouseEvents` flag

**Verification:**

```bash
xcodebuild test -scheme CoverUp -only-testing:CoverUpTests/OverlayWindowTests
```

---

### Task-003: MaskRegion Model and Manager

**Priority:** High
**Estimated Iterations:** 2

**Data structure (must match spec exactly):**

```swift
struct MaskRegion {
    var id: String                 // UUID string
    var targetWindowTitle: String? // nil = static position
    var relativeRect: CGRect       // screen-space frame
    var useBlur: Bool              // false = black box (Phase 1)
    var isActive: Bool             // hidden when false
}
```

**Acceptance Criteria:**

- [ ] `MaskRegion` struct defined as above
- [ ] `MaskRegionManager` class/actor manages a `[MaskRegion]` array
- [ ] `addRegion(_:)` appends a region and notifies observers
- [ ] `removeRegion(id:)` removes by ID
- [ ] `toggleRegion(id:)` flips `isActive`
- [ ] `regions` property is observable (Combine `@Published` or delegate callback)
- [ ] Unit tests cover: add, remove, toggle, duplicate-id handling

**Verification:**

```bash
xcodebuild test -scheme CoverUp -only-testing:CoverUpTests/MaskRegionManagerTests
```

---

### Task-004: Window Tracker

**Priority:** High
**Estimated Iterations:** 3

Poll `CGWindowListCopyWindowInfo` at ~30 FPS and update `MaskRegion.relativeRect` for any region
whose `targetWindowTitle` matches a visible window.

**Acceptance Criteria:**

- [ ] `WindowTracker` class polls on a background queue using `Timer` or `CADisplayLink`
- [ ] Polls at ~30 FPS (interval ≤ 33 ms)
- [ ] For each active, window-tracking `MaskRegion`, queries `CGWindowListCopyWindowInfo` for
  `kCGWindowName` match and retrieves `kCGWindowBounds`
- [ ] Converts CGWindow coordinates (top-left origin) to AppKit coordinates (bottom-left origin)
  accounting for Retina scale (`NSScreen.backingScaleFactor`)
- [ ] Static regions (no `targetWindowTitle`) are left unchanged
- [ ] Tracker exposes a delegate/callback so `OverlayView` is told to redraw after each update
- [ ] `WindowTracker` can be started and stopped
- [ ] Unit tests use a mock `CGWindowListProvider` protocol to inject deterministic window data;
  verify coordinate conversion and region update logic

**Verification:**

```bash
xcodebuild test -scheme CoverUp -only-testing:CoverUpTests/WindowTrackerTests
```

---

### Task-005: Rendering Engine

**Priority:** High
**Estimated Iterations:** 2

Draw all active `MaskRegion` rectangles inside `OverlayView`.

**Acceptance Criteria:**

- [ ] `OverlayView.draw(_:)` iterates `MaskRegionManager.regions`
- [ ] Active regions with `useBlur == false` are drawn as filled black rectangles
- [ ] Inactive regions (`isActive == false`) are not drawn
- [ ] `OverlayView` calls `needsDisplay = true` when notified of region updates
- [ ] Off-screen rendering test: render known regions into an off-screen `NSBitmapImageRep`,
  sample pixel colors at region centers — must be black (0,0,0,1)
- [ ] Off-screen rendering test: pixels outside all regions are fully transparent (alpha = 0)
- [ ] No visible tearing or blank frames during rapid region-position updates

**Verification:**

```bash
xcodebuild test -scheme CoverUp -only-testing:CoverUpTests/OverlayViewTests
```

---

### Task-006: Hotkeys and Control Panel

**Priority:** Medium
**Estimated Iterations:** 3

Minimal UI for runtime control: global hotkeys and a lightweight panel listing regions.

**Acceptance Criteria:**

- [ ] Menu bar `NSStatusItem` (icon + menu) as the app's primary UI entry point; no Dock icon
  (`LSUIElement = YES` in `Info.plist`)
- [ ] Global hotkeys registered via `NSEvent.addGlobalMonitorForEvents`:
  - `⌘⇧H` — toggle overlay visibility (show/hide `OverlayWindow`)
  - `⌘⇧A` — add a new static mask region (centered on main screen, 200×100 pt)
  - `⌘⇧D` — remove the most recently added region
- [ ] Control panel `NSPanel` (activatable, non-main) lists all regions with:
  - Region ID (truncated) and target window title (or "Static")
  - Enable/Disable checkbox bound to `isActive`
  - Delete button
- [ ] Control panel can be opened from the status menu
- [ ] Unit tests verify hotkey handler logic (using fake event dispatch, not real global monitors)

**Verification:**

```bash
xcodebuild test -scheme CoverUp -only-testing:CoverUpTests/HotkeyHandlerTests
```

---

### Task-007: Integration and End-to-End Tests

**Priority:** High
**Estimated Iterations:** 3

Wire all components together and verify the full pipeline.

**Acceptance Criteria:**

- [ ] `AppDelegate` (or `App` entry point) creates and connects: `MaskRegionManager`,
  `WindowTracker`, `OverlayWindow`, `OverlayView`, and hotkey handler
- [ ] Integration test: add 2 mock regions, start tracker with mock provider moving windows
  every frame, assert `MaskRegion.relativeRect` values converge to expected positions within
  5 frames
- [ ] Integration test: toggle overlay visibility — `OverlayWindow.isVisible` flips
- [ ] Performance test: 10 active regions, 30 FPS loop runs for 3 seconds, assert no frame takes
  longer than 50 ms (XCTest `measure {}`)
- [ ] XCUITest: launch app, open control panel via status menu, verify at least one region row
  appears after simulated add-region hotkey
- [ ] `README.md` documents how to grant Screen Recording permission and run tests

**Verification:**

```bash
xcodebuild test -scheme CoverUp
```

---

## Technical Constraints

- **Language:** Swift 5.9+
- **UI Framework:** AppKit (no SwiftUI for the overlay; SwiftUI acceptable for control panel only)
- **Minimum macOS:** 12.0 (Monterey)
- **Testing:** XCTest (unit + integration), XCUITest (UI automation)
- **No third-party dependencies** — public Apple APIs only
- **Screen Recording permission** required at runtime; app must gracefully prompt if missing

---

## Architecture Notes

- Single `OverlayWindow` spanning all screens; all mask regions drawn in one pass
- `MaskRegionManager` is the single source of truth; both tracker and view observe it
- `WindowTracker` runs on a background `DispatchQueue`; UI updates dispatched to main queue
- Coordinate system: CGWindow uses top-left origin; AppKit uses bottom-left — conversion is
  mandatory and must account for `NSScreen.visibleFrame` and `backingScaleFactor`
- Protocol-based `CGWindowListProvider` enables dependency injection for unit tests

---

## Out of Scope (Phase 1)

- GPU blur / Metal-based rendering
- Pixelation or mosaic masking
- AI-based sensitive-field detection
- Multi-user collaboration or cloud sync
- Persistent region profiles
- Multi-monitor coordinate edge cases beyond basic union-frame coverage
