# ShareX macOS Platform

This repository contains the native macOS platform implementation for the ShareX app, built with SwiftUI and AppKit. The repository root exposes a Swift package manifest for direct `swift run ShareX` use, while the app project also keeps its own manifest and packaging script.

The existing Windows desktop target uses `net9.0-windows10.0.22621.0` and WinForms. The macOS platform target lives under the existing `ShareX` app tree and builds a native `ShareX.app` around the core ShareX workflow:

- full-screen, selection, and window capture
- PNG output to `~/Pictures/ShareX`
- optional clipboard copy after capture
- recent capture history
- reveal, open, copy, and delete actions
- menu-bar capture commands

## Build

```sh
swift build
```

## Run

```sh
swift run ShareX
```

## Create ShareX.app

```sh
cd ShareX
./Scripts/package-macos-app.sh
open .build/app/ShareX.app
```

macOS may ask for Screen Recording permission the first time a capture is taken.
