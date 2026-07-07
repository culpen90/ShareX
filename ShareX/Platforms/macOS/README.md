# ShareX for macOS

This directory contains the native macOS implementation of ShareX. It is the
only app target in this repository.

The root package manifest builds the same target for direct `swift run ShareX`
use, and `ShareX/Scripts/package-macos-app.sh` creates a local `ShareX.app`
bundle.

Core capture modes include full screen, selection/region, window, active window,
active monitor, choose monitor, and last region. Capture settings include a
screenshot delay and cursor include/exclude control.

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
