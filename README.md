# notchActions

A native macOS menu-bar utility that turns the MacBook notch into an interactive, persistent, animated shelf.

The app is **fully hidden** — no Dock icon and no menu-bar item. Move the cursor to the notch (or drag a file toward it) and a dark, notch-hugging panel expands downward: a place to stash files, folders, and apps, drag things in and out like in Finder, and turn clipboard text into Markdown notes. Inspired by the Dynamic Island, focused on productivity.

## How it works

- **Summon it:** move the cursor to the notch, or start dragging a file toward the notch — the shelf drops down. It collapses again shortly after the cursor leaves.
- **Layout:** a configurable grid of slots. The top row wraps the notch — its slots split into a left group and a right group with a centered gap that lines up with the physical notch — and any lower rows run full width. The default is a top row of seven that wraps the notch as two slots on the left and two on the right, plus a full row of six below. Set the number of rows and the slot count of each row from the gear menu's **Layout** submenu; the shelf re-lays-out live.
- **Add:** click a slot's **+** for a native open panel, or drag files / folders / apps straight from Finder onto a slot.
- **Bundles (several files in one slot):** drag more than one file onto a single slot and they stack into a bundle — the slot shows fanned icons with a count badge and an "N items" label. Clicking a bundle opens every file at once; dragging it out hands over all of the files; copying it copies all of them. Right-click ▸ *Fill from Clipboard* appends a clipboard note to the slot's bundle.
- **Open:** single-click an item to open the file, launch the app, or open the folder in Finder. For a bundle, every file opens.
- **Copy:** the **clipboard** button at a slot's top-left (on hover) copies the item — or the whole bundle — as real file references, ready to paste into Finder or any app.
- **Drag out:** drag an item from the shelf into Finder or another app — it lands as the real file (every file, for a bundle) and stays on the shelf.
- **Rearrange:** drag one slot onto another to swap.
- **Remove:** the **−** button on hover, or right-click ▸ *Remove from Shelf* (the files stay on disk).
- **Right-click a slot** for Open / Reveal in Finder / Copy Path / Copy to Clipboard / Fill from Clipboard / Remove. Right-click an empty slot for Fill from Clipboard / Add File. A broken item offers Locate… / Remove.
- **Hover preview:** a small popover with a Quick Look thumbnail, a text snippet, or a folder info table — for a bundle, a list of its files. The thumbnail and each list row are clickable to open that file, and a copy button at the top-right copies the item.
- **Menu / Quit:** the **gear** control in the shelf — Paste Clipboard as Markdown, Clear Shelf, Clear Cache, Hide Shelf, Layout ▸, Open at Login, Quit. **Clear Cache** deletes the Markdown notes the app created from your clipboard and removes them from the shelf; **Clear Shelf** only drops the shelf's references and leaves every file on disk.

## Features

- Notch-aligned floating panel with invisible collapsed and expanded states, smooth spring animation
- Hover and drag-toward-notch activation (drop without clicking first)
- Configurable grid: 1–4 rows with 1–8 slots each, set from the gear menu's Layout submenu; the top row wraps the notch with a centered gap, and the shelf re-lays-out live
- Drag files, folders, and apps into slots; drag them back out into Finder as real files
- Multi-file bundles: drop several files into one slot for a stacked, badged bundle — click opens all, drag-out hands over all, copy and clipboard act on the whole bundle
- Copy as real file references from a slot's top-left button or the preview's top-right button — paste into Finder or any app
- Persistent shelf (survives quit, restart, reboot) via security-scoped bookmarks — never copies, moves, or deletes your files
- Rearrange by swapping slots; remove from shelf without touching the originals
- Create a Markdown file from clipboard text (plain or rich text), stored locally and added to the shelf; Fill from Clipboard targets a specific slot
- Clear Cache removes the app-created clipboard notes (files and references), distinct from Clear Shelf, which only drops references
- Native Finder/Dock icons; broken items show a warning and a right-click "Locate…" to relink a moved file
- Launch at login (toggle in the gear menu)
- Hover preview: a Quick Look thumbnail, a scrollable text snippet, a folder info table, or a bundle's file list — click the thumbnail or a row to open, copy from the top-right button
- ⌘V with the shelf open pastes the clipboard into a free slot as a Markdown note
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

- `notchActions/` — app sources: the model (`ShelfStore`, `ShelfItem` bundles of `ShelfFile`, `ShelfLayoutConfig` / `LayoutConfigStore`, `ShelfGrid` layout math), SwiftUI views (`ShelfView`, `SlotView`, `ShelfPreviewView`), and the AppKit window/trigger layer (`ShelfWindowController`, `ShelfPanel`, `NotchGeometry`)

## License

All rights reserved.
