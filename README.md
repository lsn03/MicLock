# MicLock

A tiny menu-bar app for macOS that **locks your default microphone**.

By default, macOS silently switches the system input to any newly-connected
Bluetooth or USB audio device. If you plug in headphones, your voice suddenly
goes through the headset mic — usually a downgrade from your real mic.

MicLock stops that. You pick an input device once; MicLock keeps it as the
system default no matter what you plug in. Output is left alone — your
headphones still play sound.

## Install

1. Download the latest `.dmg` from
   [Releases](https://github.com/lsn03/MicLock/releases).
2. Open it and drag **MicLock** into **Applications**.
3. In `/Applications`: **right-click MicLock → Open → Open**.
   (Only needed once — Gatekeeper warns because the build is ad-hoc signed.)

An icon appears in the menu bar. Click to pick your mic; a check mark marks
the locked one. Toggle `Launch at Login` so it starts with your Mac.

## Features

- Locks the default input device across reconnects.
- Keeps output on auto (headphones still get the sound).
- Menu stays open while you scan your devices; 30-second inactivity
  auto-close.
- Live device-list refresh while the menu is open.
- Launches at login via `SMAppService`.
- Pure Swift + AppKit + CoreAudio. No background daemon, no polling.

## Build from source

Requires macOS 13+ and Xcode Command Line Tools (`xcode-select --install`).

```bash
git clone https://github.com/lsn03/MicLock.git
cd MicLock
./build.sh                 # produces build/MicLock.app
./release.sh               # produces build/MicLock-<version>.dmg
```

Icons are generated from SVG via `rsvg-convert` + `iconutil`:

```bash
brew install librsvg
./design/build-icons.sh    # regenerates Resources/AppIcon.icns + MicLockTemplate.pdf
```

## Project layout

```
Sources/MicLock/
  main.swift              bootstrap
  AppDelegate.swift       status item + menu
  AudioController.swift   CoreAudio listeners + enforcement
  DeviceRowView.swift     custom menu row (hover + non-dismissing click)
  CheckboxRowView.swift   same, for preference toggles
  Settings.swift          UserDefaults wrapper
Resources/
  Info.plist              LSUIElement, SMAppService, icon
  AppIcon.icns            app icon
  MicLockTemplate.pdf     menu-bar template image
design/
  concepts/               source SVGs
  build-icons.sh          SVG → icns/pdf
```

## License

MIT.
