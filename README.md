# NotchShelf

A native macOS menu-bar utility that turns the MacBook notch into an interactive, persistent, animated shelf.

Move the cursor to the notch and a polished panel expands downward — a place to stash files, folders, and apps, drag things in and out like in Finder, and turn clipboard text into Markdown notes. Inspired by the Dynamic Island, focused on productivity.

## Features (MVP)

- Notch-aligned floating panel with collapsed and expanded states, smooth spring animation
- Expand on hover and on drag-toward-notch (drop without clicking first)
- Drag files, folders, and apps into fixed slots; drag them back out into Finder as real files
- Add items via a native open panel; click to open, launch, or reveal
- Persistent shelf (survives quit, restart, reboot) using security-scoped bookmarks — never copies or moves your files
- Rearrange by dragging between slots; remove with a per-item button
- Create a Markdown file from clipboard text, stored locally and added to the shelf
- Menu-bar menu, native icons, graceful handling of missing or moved files

## Requirements

- macOS 14 Sonoma or later
- Xcode 16+

## Build

```sh
xcodebuild -project notchActions.xcodeproj -scheme notchActions -configuration Debug build
```

Or open `notchActions.xcodeproj` in Xcode and run.

## Project layout

- `notchActions/` — app sources
- `docs/specs.md` — full technical specification
- `docs/plan.md` — detailed, phased build plan

## License

All rights reserved.
