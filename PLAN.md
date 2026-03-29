# RFC: Multi-Area Real-Time Blur/Overlay Tool for macOS

## 1. Title

**Multi-Area Real-Time Blur/Overlay Tool for macOS** – Phase 1 MVP

---

## 2. Objective

Develop a macOS application that allows users to **hide or blur multiple sensitive regions** on the screen in **real-time**, with the ability to **track moving windows or UI elements**, without requiring post-processing or video editing.

The MVP focuses on **functionality over polish**, with the option to later upgrade to full GPU-based blur.

---

## 3. Background and Motivation

* **Problem:** macOS currently provides no native feature to censor or blur arbitrary screen areas in real time. Users rely on post-processing tools like DaVinci Resolve or manual overlays.
* **Use cases:** Screen recording, live streaming, demos, tutorials, coding walkthroughs, API key masking.
* **Goal:** Reduce post-processing, improve workflow efficiency, and allow sensitive information to be hidden live.

---

## 4. Scope

### Phase 1 MVP Features

* Multi-area overlay support
* Window or screen-region tracking
* Black-box masking (Phase 1; blur can be added later)
* Always-on-top overlay, click-through
* Configurable per region (enable/disable, resize, move)
* Basic hotkeys (toggle overlay, add/remove regions)

### Out of scope for Phase 1

* True GPU blur or pixelation
* AI-based object detection
* Multi-user collaboration
* Persistent profiles or cloud sync

---

## 5. Requirements

### 5.1 Functional Requirements

| ID    | Requirement        | Description                                                                  |
| ----- | ------------------ | ---------------------------------------------------------------------------- |
| FR-01 | Multi-area overlay | Support multiple regions to blur/cover simultaneously                        |
| FR-02 | Tracking           | Each region can track a target window by title or a static screen coordinate |
| FR-03 | Overlay window     | Always-on-top, borderless, transparent, click-through                        |
| FR-04 | Mask type          | Each region can be solid color or future blur                                |
| FR-05 | Real-time update   | Regions update at ~30 FPS to follow moving windows                           |
| FR-06 | User interaction   | Users can add/remove regions, toggle visibility                              |
| FR-07 | Rendering          | All regions drawn in a single overlay window                                 |

### 5.2 Non-Functional Requirements

| ID     | Requirement   | Description                                                        |
| ------ | ------------- | ------------------------------------------------------------------ |
| NFR-01 | Performance   | Overlay updates smoothly without perceptible lag (<33ms per frame) |
| NFR-02 | Security      | Uses only public macOS APIs; cannot inject code into other apps    |
| NFR-03 | Reliability   | Overlay remains on top and tracks windows consistently             |
| NFR-04 | Compatibility | Works on macOS 12+ (Monterey onwards)                              |
| NFR-05 | Permissions   | Requires user-granted Screen Recording permission                  |

---

## 6. System Architecture

### 6.1 Components

1. **Overlay Window**

   * Single transparent NSWindow
   * Renders all mask regions
   * Always-on-top, click-through

2. **Mask Region Manager**

   * Stores all `MaskRegion` objects
   * Handles updates, adding/removing regions

3. **Tracker**

   * Polls window positions using `CGWindowListCopyWindowInfo`
   * Updates region positions each frame

4. **Rendering Engine**

   * Draws rectangles (black boxes or blur) in overlay window
   * Uses `NSView.draw(_:)` for Phase 1; Metal/Core Image for blur later

5. **User Interface**

   * Hotkeys and minimal config window
   * List of regions with enable/disable toggle, resize, move

---

### 6.2 Data Structures

```swift
struct MaskRegion {
    var id: String                 // unique identifier
    var targetWindowTitle: String? // if tracking a window
    var relativeRect: CGRect       // position & size
    var useBlur: Bool              // black box vs future blur
    var isActive: Bool             // enable/disable
}
```

* `MaskRegion` objects stored in an array for iteration during render cycle.

---

### 6.3 Tracking Algorithm

1. Poll windows every frame (~30 FPS)
2. For each `MaskRegion`:

   * If `targetWindowTitle` is defined:

     * Query CGWindow API to find current bounds
     * Update `relativeRect` to match
   * Else: Maintain static position
3. Redraw overlay

> Optional: smooth transitions with interpolation to reduce jitter.

---

### 6.4 Rendering Algorithm

1. Overlay NSWindow draws once per frame
2. For each `MaskRegion`:

   * Draw black rectangle or blur
   * Apply alpha for semi-transparency if desired
3. Frame is composited in the single overlay window

> Phase 1 uses simple black boxes for MVP.

---

## 7. Permissions & Security Considerations

* Requires **Screen Recording** permission in macOS System Preferences
* Does **not** inject code into other apps
* Overlay is click-through to prevent interference

---

## 8. User Interaction

* **Hotkeys:**

  * Toggle overlay visibility
  * Add new mask region
  * Remove selected mask region

* **Overlay window interaction:**

  * Drag/resize mask regions if auto-tracking fails
  * Toggle enable/disable per region

---

## 9. Extensibility / Future Phases

* GPU-accelerated blur using Metal/Core Image
* AI-powered auto detection of sensitive fields
* Pixelation option
* Multi-monitor support
* Persistent profiles for app-specific masks
* Integration with recording/streaming software

---

## 10. Technical Stack

* Language: Swift
* UI Framework: AppKit (transparent overlay window)
* Graphics: Core Graphics / Core Image for Phase 1; Metal for GPU blur later
* Window tracking: CGWindow API
* Timer loop: `Timer` or `CADisplayLink` for ~30 FPS updates

---

## 11. Risks & Challenges

| Risk                                       | Mitigation                                                             |
| ------------------------------------------ | ---------------------------------------------------------------------- |
| Overlay performance lags on older machines | Use lightweight black boxes initially, optimize render loop            |
| Window tracking fails for certain apps     | Allow manual region adjustment                                         |
| macOS security restrictions                | Use only public APIs; require user-granted Screen Recording permission |
| Multiple monitors / Retina scaling issues  | Test on multi-display setups; account for coordinate scaling           |

---

## 12. Success Metrics

* MVP correctly tracks at least **2 moving windows** simultaneously
* Overlay updates smoothly at **30 FPS**
* Users can add/remove **multiple mask regions** without app crash
* Screen recording captures masked areas correctly

---

## 13. Automated Testing

### 13.1 Objective

Provide a test framework that can verify the following **without manual intervention**:

* Overlay window exists, is always on top, and click-through
* Multiple mask regions can be added, removed, and toggled
* Mask regions track their target windows correctly
* Mask regions render properly (black box or blur)
* Timer-based updates (~30 FPS) move regions according to target windows
* Hotkeys and region management logic function correctly

---

### 13.2 Approach

1. **Unit Testing** – Validate logic independent of UI
2. **Integration Testing** – Validate overlay and tracking logic
3. **Automated UI Testing** – Simulate window creation, movement, and check overlay behavior

---

### 13.3 Tools

| Type                   | Tool                      | Purpose                                              |
| ---------------------- | ------------------------- | ---------------------------------------------------- |
| Unit/Integration       | XCTest                    | Test mask manager, tracker, rendering logic          |
| UI Automation          | XCUITest                  | Simulate app interactions, window movements, hotkeys |
| Window Simulation      | CGWindow API mock         | Mock target windows for deterministic tests          |
| Rendering Verification | Off-screen NSView capture | Compare overlay rendering against expected masks     |

---

### 13.4 Test Components

**Unit Tests (XCTest)**

* Adding/removing mask regions
* Toggling `isActive` and `useBlur`
* Tracker updates mock window positions correctly
* Off-screen rendering verifies rectangle bounds

**Integration Tests**

* Simulate multiple mock windows moving
* Verify overlay regions stay aligned
* Overlay window is always-on-top and click-through

**Automated UI Tests (XCUITest)**

* Launch application
* Create 2–3 mock windows
* Add mask regions for each window
* Move mock windows programmatically
* Assert overlay regions track windows correctly
* Enable/disable regions via code (simulate hotkeys)
* Capture overlay frame buffer to verify rendering

---

### 13.5 Test Data / Mocks

* Mock windows with fixed titles and predictable coordinates
* Mock regions with known relative coordinates
* Optional: create minimal dummy NSWindows for testing

---

### 13.6 Verification Criteria

| Feature           | Verification Method     | Pass Condition                              |
| ----------------- | ----------------------- | ------------------------------------------- |
| Overlay window    | NSWindow properties     | Exists, always-on-top, click-through        |
| Multi-area masks  | MaskRegion array        | Multiple regions exist and render correctly |
| Tracking          | Mock window move        | Overlay region moves in sync                |
| Toggle visibility | Programmatically toggle | Overlay reflects enable/disable state       |
| Add/remove mask   | Add/remove calls        | MaskRegion array updates accordingly        |
| FPS updates       | Timer loop              | Overlay redraws ~30 FPS (±5%)               |
