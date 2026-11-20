# KeyView — Spec

## Goal

A small macOS app. It shows the keyboard layout in a window.
Each key has the color of the finger that should press it.

## Keyboard

- MacBook ANSI layout. No numpad.
- Rows: function row, number row, 3 letter rows, bottom row with modifiers and Space.

## Key labels

- Labels come from the current macOS input source (EN, RU, any other).
- When the user switches the input source, labels update at once.
- Each key shows the main symbol large.
- The Shift symbol is small and dim, in the corner.
- While Shift is held, the Shift symbol becomes the main one.

## Finger colors

- 4 colors: pinky, ring, middle, index. Same colors on both hands (mirrored).
- Index finger: the inner column (5 T G B, 6 Y H N) uses a lighter shade of the index color.
- Modifiers, function row: neutral color.
- Space: thumb color.

| Finger | Left hand        | Right hand                          |
|--------|------------------|-------------------------------------|
| Pinky  | ` 1 Q A Z, Tab, Caps, Shift | 0 P ; / - = [ ] \ ' , Delete, Return, Shift |
| Ring   | 2 W S X          | 9 O L .                             |
| Middle | 3 E D C          | 8 I K ,                             |
| Index  | 4 R F V + 5 T G B (lighter) | 7 U J M + 6 Y H N (lighter) |

## Pressed keys

- A pressed key is highlighted while it is down.
- This needs the Input Monitoring permission. Without it, the app works, just without highlight and Shift layer.

## Window

- Stays on top of other windows, on all Spaces, also over full-screen apps.
- Can be resized. Keyboard scales and keeps its proportions.
- Opacity can be changed. Default: not transparent.
- Clicks do not pass through the window.
- Remembers its position and size.

## Theme

- Follows the system: light or dark.

## App

- Menu bar icon. No Dock icon.
- Menu: Show/Hide window, Opacity slider, Quit.

## Tech

- Swift, SwiftUI + AppKit.
- Swift Package, built with `swift build`. A script packs the binary into `KeyView.app`. Xcode is not needed.
