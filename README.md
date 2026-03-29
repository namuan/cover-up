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

## Screen Recording Permission

CoverUp uses `CGWindowListCopyWindowInfo` to track window positions. On first launch, macOS will
prompt for Screen Recording permission. If it doesn't appear automatically, grant it via:

**System Settings → Privacy & Security → Screen Recording → CoverUp**

The app sandbox is disabled (`com.apple.security.app-sandbox = false`) so the CGWindow API
can access window information from other applications.
