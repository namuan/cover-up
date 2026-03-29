# CoverUp

A macOS menu bar application that hides multiple sensitive screen regions in real-time using
always-on-top, click-through black-box overlays. Regions can track moving windows by title or
sit at static coordinates.

**Stack:** Swift · AppKit · Core Graphics · CGWindow API

## Requirements

- macOS 12.0+
- Xcode 15+

## Build

```bash
xcodebuild -scheme CoverUp -destination 'platform=macOS' build
```

## Test

```bash
xcodebuild test -scheme CoverUp -destination 'platform=macOS'
```

## Permissions Required

### Screen Recording
1. Go to System Settings → Privacy & Security → Screen Recording
2. Add CoverUp and enable it
3. Restart CoverUp

CoverUp uses `CGWindowListCopyWindowInfo` to track window positions. On first launch, macOS will
prompt for Screen Recording permission. If it doesn't appear automatically, follow the steps above.

The app sandbox is disabled (`com.apple.security.app-sandbox = false`) so the CGWindow API
can access window information from other applications.

### Accessibility (for global hotkeys)
1. Go to System Settings → Privacy & Security → Accessibility
2. Add CoverUp and enable it

## Running Tests

```bash
xcodebuild test -scheme CoverUp -destination 'platform=macOS'
```
