# ShareX for macOS

ShareX is now a macOS-exclusive screenshot utility built with SwiftUI and AppKit.
The Windows/.NET desktop application, installer projects, and Windows-specific
CI have been removed from this repository.

The native macOS app supports:

- full-screen, selection/region, window, active-window, monitor, and last-region capture
- PNG output to `~/Pictures/ShareX`
- optional clipboard copy after capture
- optional screenshot delay and cursor capture
- recent capture history
- reveal, open, copy, and delete actions
- menu-bar capture commands

## Requirements

- macOS 13 or newer
- Xcode command line tools with Swift 5.9 or newer

## Build

```sh
swift build
```

## Run

```sh
swift run ShareX
```

## Package

```sh
cd ShareX
./Scripts/package-macos-app.sh
open .build/app/ShareX.app
```

macOS may ask for Screen Recording permission the first time a capture is taken.
