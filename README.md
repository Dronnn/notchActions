# notchActions

A native macOS menu-bar utility that turns the MacBook notch into an interactive, persistent, animated shelf.

The app is **fully hidden** — no Dock icon and no menu-bar item. Move the cursor to the notch (or drag a file toward it) and a dark, notch-hugging panel expands downward: a place to stash files, folders, and apps, drag things in and out like in Finder, and turn clipboard text into Markdown notes. Inspired by the Dynamic Island, focused on productivity.

## How it works

- **Summon it:** move the cursor to the notch, or start dragging a file toward the notch — the shelf drops down. It collapses again shortly after the cursor leaves.
- **Layout:** eight fixed slots wrap the notch in a U (two down the left, four across the bottom, two down the right), leaving the notch-facing center open.
- **Add:** click a slot's **+** for a native open panel, or drag files / folders / apps straight from Finder onto a slot.
- **Open:** single-click an item to open the file, launch the app, or open the folder in Finder.
- **Drag out:** drag an item from the shelf into Finder or another app — it lands as the real file and stays on the shelf.
- **Rearrange:** drag one slot onto another to swap.
- **Remove:** the **−** button on hover, or right-click ▸ *Remove from Shelf* (the file stays on disk).
- **Right-click** an item for Open / Reveal in Finder / Copy Path / Remove.
- **Menu / Quit:** the **gear** control in the shelf — Paste Clipboard as Markdown, Clear Shelf, Hide Shelf, Open at Login, Quit.

## Features

- Notch-aligned floating panel with invisible collapsed and expanded states, smooth spring animation
- Hover and drag-toward-notch activation (drop without clicking first)
- Drag files, folders, and apps into fixed slots; drag them back out into Finder as real files
- Persistent shelf (survives quit, restart, reboot) via security-scoped bookmarks — never copies, moves, or deletes your files
- Rearrange by swapping slots; remove from shelf without touching the original
- Create a Markdown file from clipboard text, stored locally and added to the shelf
- Native Finder/Dock icons; graceful broken-item state when a file is moved or deleted
- Launch at login (toggle in the gear menu)
- Hover preview: a Quick Look thumbnail (or first text lines) with name and type/size
- The shelf unrolls from the notch (grows from a notch-sized footprint to full)

## Requirements

- macOS 14 Sonoma or later
- Xcode 16+

## Build & run

Open `notchActions.xcodeproj` in Xcode and run, or:

```sh
xcodebuild -project notchActions.xcodeproj -scheme notchActions -configuration Debug build
```

The app runs as a background agent (`LSUIElement`, not sandboxed). After launch, move the cursor to the notch to reveal the shelf.

## Project layout

- `notchActions/` — app sources: the `ShelfStore` / `ShelfItem` model, SwiftUI views (`ShelfView`, `SlotView`), and the AppKit window/trigger layer (`ShelfWindowController`, `ShelfPanel`, `NotchGeometry`)

## License

All rights reserved.
