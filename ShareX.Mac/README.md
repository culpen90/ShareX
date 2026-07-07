# ShareX for macOS

This directory contains a native macOS companion app for ShareX, built with SwiftUI and AppKit.

The existing ShareX codebase is a Windows desktop application that targets `net9.0-windows10.0.22621.0` and WinForms. This macOS app does not try to compile that Windows UI stack on macOS; it starts a native Mac surface around the core ShareX workflow:

- full-screen, selection, and window capture
- PNG output to `~/Pictures/ShareX`
- optional clipboard copy after capture
- recent capture history
- reveal, open, copy, and delete actions
- menu-bar capture commands

## Build

```sh
cd ShareX.Mac
swift build
```

## Run

```sh
cd ShareX.Mac
swift run ShareXMac
```

## Create ShareX.app

```sh
cd ShareX.Mac
./Scripts/bundle-app.sh
open .build/app/ShareX.app
```

macOS may ask for Screen Recording permission the first time a capture is taken.
