# NotchShelf — Detailed Build Plan

## How to use this plan
- This plan is the build order. **`specs.md` is the source of truth for behavior and visual detail.** Each step cites the relevant `specs.md §` — **read that section of `specs.md` whenever you start a step that references it, and whenever a detail here is ambiguous.** The plan is the skeleton; the spec is the flesh. When in doubt, the spec wins.
- Build after every phase; never proceed on a red build.

## Context
Build a native macOS menu-bar utility (`notchActions` / "NotchShelf") that turns the MacBook notch into an interactive, persistent, animated drag-and-drop shelf. The Xcode project exists but holds only the default SwiftUI + SwiftData template (`notchActionsApp.swift`, `ContentView.swift`, `Item.swift`, plus test targets). This is an ordered, dependency-respecting, fully-detailed step list to take the project from empty template to a complete MVP matching `specs.md` §36, executable end-to-end without interruption.

**Stack:** Swift 5, AppKit (`NSPanel`, `NSStatusItem`, drag/drop, screen detection) + SwiftUI rendered inside the panel via `NSHostingView`. No sandbox for MVP. Security-scoped bookmarks anyway for resilience. No network, no Electron.

## Project facts the agent MUST know before starting
- **Synchronized groups:** `project.pbxproj` uses `objectVersion = 77` with `PBXFileSystemSynchronizedRootGroup`. **Any `.swift` file placed inside the `notchActions/` folder is automatically compiled** — do NOT hand-edit `project.pbxproj` to register source files. Just create the file in `notchActions/`.
- **Build-setting changes still require editing `project.pbxproj`** (there is no `Info.plist` file — `GENERATE_INFOPLIST_FILE = YES`, settings come from `INFOPLIST_KEY_*`). Settings appear twice: Debug and Release configs — **edit both**.
- Current relevant settings (app target only — leave test targets alone): `ENABLE_APP_SANDBOX = YES` (→ change to NO), `MACOSX_DEPLOYMENT_TARGET = 15.6` (→ 14.0), `PRODUCT_BUNDLE_IDENTIFIER = notchActions.mrmaier.com.notchActions`, `SWIFT_VERSION = 5.0`.
- **Storage:** human-readable folder `NotchShelf` under Application Support.
- **Build command:** `xcodebuild -project notchActions.xcodeproj -scheme notchActions -configuration Debug build` (or Xcode MCP `BuildProject`). **Build after every phase; do not proceed on a red build.**
- **Locked decisions:** no sandbox; rearrange = swap; duplicates = reject + highlight existing; fixed 8 slots single row; macOS 14; main display only for v1 (geometry structured for multi-display later); shelf above normal windows but not over fullscreen apps; clipboard→md trigger = menu-bar item only.
- **Style:** no AI attribution anywhere (comments, commits). Author = Andreas Maier. Plain, human comments or none.

---

## Phase 0 — Project surgery & app shell

### 0.1 Remove template code
- Delete `notchActions/ContentView.swift` and `notchActions/Item.swift`.
- Replace `notchActions/notchActionsApp.swift` body entirely (remove all SwiftData / `ModelContainer`):
  ```swift
  import SwiftUI

  @main
  struct NotchShelfApp: App {
      @NSApplicationDelegateAdaptor(AppController.self) private var appController
      var body: some Scene { Settings { EmptyView() } }
  }
  ```
  (`Settings { EmptyView() }` gives a valid `Scene` with no visible window.)

### 0.2 Build settings (edit `project.pbxproj`, BOTH Debug & Release of the app target)
- `ENABLE_APP_SANDBOX = YES` → `NO`.
- `MACOSX_DEPLOYMENT_TARGET = 15.6` → `14.0`.
- Add `INFOPLIST_KEY_LSUIElement = YES` (menu-bar utility: no Dock icon, no main menu/window).
- Confirm no `CODE_SIGN_ENTITLEMENTS` forces sandbox; if an entitlements file exists, set `com.apple.security.app-sandbox` to `false` ("Sign to Run Locally").

### 0.3 `AppController.swift` (new, in `notchActions/`)
- `final class AppController: NSObject, NSApplicationDelegate`.
- Properties: `private var statusItem: NSStatusItem?` now; add `store` (Phase 2) and `shelfWindowController` (Phase 4) when those phases land.
- `applicationDidFinishLaunching(_:)`: `NSApp.setActivationPolicy(.accessory)`; build a minimal status item (Phase 0: `systemSymbolName: "tray.full"` button + a menu with only **Quit**). Full menu in Phase 14.
- **Done when:** app builds, launches, shows a menu-bar icon, no Dock icon, no window; Quit works.

---

## Phase 1 — Logging
*(spec §35)*
### 1.1 `Log.swift`
- `import os`. `enum Log` with static `Logger`s per category using subsystem `Bundle.main.bundleIdentifier ?? "NotchShelf"`: `lifecycle`, `dragdrop`, `persistence`, `clipboard`, `geometry`.
- Use throughout for every event in spec §35 (app launched, shelf shown/hidden, file added/opened/removed, drag entered/drop completed, bookmark resolved/failed, clipboard note created, persistence save/load failed).
- **Done when:** builds; an `info` line appears in Console on launch.

---

## Phase 2 — Model, paths, bookmarks, store
*(spec §13, §24, §25, §38)*
### 2.1 `AppPaths.swift`
- `enum AppPaths`: `supportDir` = Application Support / `NotchShelf` (created with intermediates); `clipboardNotesDir` = `supportDir/Clipboard Notes`; `storeFile` = `supportDir/shelf.json`. Each accessor creates the dir if missing; log on failure.

### 2.2 `ShelfItem.swift` *(spec §38)*
- ```swift
  struct ShelfItem: Identifiable, Codable, Equatable {
      let id: UUID
      var slotIndex: Int
      var kind: ShelfItemKind
      var displayName: String
      var bookmarkData: Data?
      var originalURLString: String?
      var createdAt: Date
      var updatedAt: Date
  }
  enum ShelfItemKind: String, Codable { case file, folder, application, markdownNote }
  ```

### 2.3 `BookmarkResolver.swift` *(spec §25)*
- `makeBookmark(for:) throws -> Data` — `url.bookmarkData(options: [.withSecurityScope]…)`.
- `resolve(_:) -> (url: URL, isStale: Bool)?` — `URL(resolvingBookmarkData:options:[.withSecurityScope]…)`; nil on throw; log.
- `classify(_:) -> ShelfItemKind` — `.app` ext → `.application`; `isDirectory` → `.folder`; else `.file`. (markdownNote assigned by clipboard service.)
- `withAccess(_:_:)` — wrap `startAccessingSecurityScopedResource()` / `defer stop…`; a `false` start in non-sandbox must NOT block access (still run body).

### 2.4 `ShelfStore.swift` *(spec §13, §31, §32)*
- `@MainActor final class ShelfStore: ObservableObject`. `static let slotCount = 8`.
- `@Published private(set) var items: [ShelfItem]` (sparse; unique `slotIndex` 0..<8). Each mutation logs + `save()`.
- Methods: `init()→load()`; `item(at:)`; `firstEmptySlot`; `emptySlots`; `resolvedURL(for:)` (bookmark→fallback originalURLString; nil = broken); `contains(url:)` (standardized-path dup check); `add(url:kind:preferredSlot:) -> AddResult { added(Int) | duplicate(existingSlot:) | shelfFull }`; `addMany(urls:startingAt:) -> (addedCount, overflow, firstDuplicateSlot)`; `remove(slot:)` (drops reference only, never deletes file); `swap(_:_:)`; `clear()` (keep files); `save()` (atomic pretty JSON to `storeFile`, never crash); `load()` (tolerate missing/corrupt → empty).
- **Done when:** temporary debug add → relaunch shows it loaded; `shelf.json` valid. Remove debug call after. Wire `store` into `AppController`.

---

## Phase 3 — Icons
*(spec §19)*
### 3.1 `IconProvider.swift`
- `@MainActor enum IconProvider`: `icon(for url: URL?, broken: Bool, size:) -> NSImage` — broken/nil → `NSImage(systemSymbolName: "exclamationmark.triangle"…)`; else `NSWorkspace.shared.icon(forFile:)` sized. Small in-memory cache keyed `path-size`, cap ~64. SwiftUI uses `Image(nsImage:)`.
- **Done when:** returns a valid icon for a known app path.

---

## Phase 4 — Notch geometry & panel window
*(spec §5, §6, §7)*
### 4.1 `NotchGeometry.swift` *(spec §5, §6)*
- `struct NotchMetrics { screen; notchRect; hasRealNotch }` (AppKit coords, origin bottom-left).
- `metrics(for:) ` — real notch: `screen.safeAreaInsets.top > 0`; width via `auxiliaryTopLeftArea`/`auxiliaryTopRightArea` gap (fallback ~200pt centered); height = safeAreaInsets.top. No notch → virtual 200×32 centered at screen top.
- `collapsedTriggerRect(_:)` — notch rect, optionally widened ~40pt per side.
- `expandedPanelRect(_:)` — width 440, height 150 (spec §6), centered on notch, top flush with `screen.frame.maxY`, growing downward, clamped to `visibleFrame`.
- Target `NSScreen.main` for v1; signature takes a screen for later multi-display.

### 4.2 `ShelfPanel.swift` *(spec §7)*
- `final class ShelfPanel: NSPanel`: `styleMask [.borderless, .nonactivatingPanel]`; `isFloatingPanel = true`; `level = .statusBar`; `isOpaque = false`; `backgroundColor = .clear`; `hasShadow = false` (shadow in content); `hidesOnDeactivate = false`; `isMovable = false`; `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]`; override `canBecomeKey/Main = false` (non-activating — hover must not steal focus) yet still receives mouse + drag.

### 4.3 `ShelfWindowController.swift` *(spec §37.2)*
- `@MainActor final class ShelfWindowController`: owns panel + `NSHostingView(rootView: ShelfView(store:uiState:))` + refs to store/uiState.
- `positionPanel()` — set panel frame to the **expanded** rect; the panel is ALWAYS physically expanded-size; collapse is done by SwiftUI shrinking/clipping content, so the window never resizes mid-animation → no flicker (anti-flicker strategy, spec §7/§9).
- `show()`/`hide()`; observe `NSApplication.didChangeScreenParametersNotification → positionPanel()`.
- **Done when:** temporary `show()` → translucent shape anchored under notch; remove forced-show after.  Wire into `AppController`.

---

## Phase 5 — Shelf UI (SwiftUI)
*(spec §6, §10, §27, §34, §41, §43)*
### 5.1 `ShelfUIState.swift`
- `@MainActor final class ShelfUIState: ObservableObject`: `isExpanded`, `isDragOver`, `hoveredSlot: Int?`, `highlightSlot: Int?` (dup flash), `fullShelfToast: Bool`; helpers `flash(slot:)` / `showFull()` that auto-clear after ~1.2s.

### 5.2 `VisualEffectBackground.swift`
- `NSViewRepresentable` over `NSVisualEffectView` (`material .hudWindow`/`.popover`, `blendingMode .behindWindow`, `state .active`). `.ultraThinMaterial` acceptable fallback.

### 5.3 `ShelfView.swift` *(spec §6, §27, §34)*
- `ZStack(alignment:.top)`. Background = custom `Shape` with **flat top corners** (hugging notch) + rounded bottom (radius ~22), filled with `VisualEffectBackground` + dark overlay + soft shadow.
- Content `VStack`: 8-slot `HStack` of `SlotView`, padding ~14.
- Collapse/expand by `uiState.isExpanded`: collapsed → content `opacity 0`, `scaleEffect(0.92, anchor:.top)`, container height 0→150 + `.clipped()`, `withAnimation(.spring(response:0.32, dampingFraction:0.82))`, anchor `.top` (grows downward).
- Empty-state hint "Drag files here or press +" when `store.items.isEmpty`, auto-hidden once any item exists (spec §34).
- Full-shelf toast capsule at bottom when `fullShelfToast` (spec §32).

### 5.4 `SlotView.swift` *(spec §10, §41, §43)*
- ~64×64 rounded rect (radius ~14). **Empty:** subtle border, centered plus as a real `Button` control (filled circle/rounded square, NOT bare glyph — spec §10.2); hover brightens border + scales plus. **Occupied:** centered `Image(nsImage: IconProvider…)` + optional truncated label (1 line, middle truncation); minus `Button` top-right on hover; hover background highlight; broken → warning icon, dimmed, no drag. `highlightSlot == index` → accent ring (dup flash).
- Minus button isolated hit area so it never triggers open. Accessibility: "Add item", "Open \(name)", "Remove \(name) from shelf" (spec §43).
- **Done when:** with sample items, expanded shelf shows 8 slots, correct icons, plus/minus, hover states.

---

## Phase 6 — Activation & animation
*(spec §8, §9, §22.2, §42)*
### 6.1 Hover trigger *(spec §8.1)*
- Always-on transparent **trigger window** sized to `collapsedTriggerRect` (borderless, `.statusBar`, transparent) hosting an `NSView` with `NSTrackingArea` `[.activeAlways, .mouseEnteredAndExited]`. `mouseEntered` → expand + `show()`.
- **Collapse:** track cursor inside expanded panel bounds; `mouseExited` → `DispatchWorkItem` after **350 ms** sets `isExpanded = false`; cancel on re-entry (debounce, spec §8.1/§22.2). Never collapse during a drag (6.3).

### 6.2 Expand/collapse animation *(spec §9)*
- Wrap state flips in `withAnimation(.spring(response:0.32, dampingFraction:0.82))`; content height/opacity/scale animate, window frame fixed → no flicker.

### 6.3 Drag activation (CRITICAL, spec §8.2)
- Register trigger + panel content for `[.fileURL]`; `draggingEntered` → expand + set `isDragging` flag that **suppresses the collapse timer** until `draggingExited`/`Ended`/`performDragOperation`. User can drag from Finder straight onto a slot without clicking first.

### 6.4 Click toggle (optional, spec §8.3)
- Click trigger toggles `isExpanded`; outside click (global `NSEvent.addGlobalMonitorForEvents(.leftMouseDown)`) collapses. Event-driven, no polling (spec §42).
- **Done when:** hover expands smoothly; leaving collapses after delay; dragging toward notch expands and stays open.

---

## Phase 7 — Drag & drop INTO the shelf
*(spec §14, §24, §32)*
### 7.1 Drop handling
- Per-`SlotView` SwiftUI `DropDelegate` (`of: [.fileURL]`): `dropEntered` → `isDragOver = true` + highlight target; `validateDrop` true for fileURL; `performDrop` → load URLs (`loadObject(ofClass: URL.self)`), main-actor `store.add(url:kind:classify, preferredSlot:thisSlot)`, rest → next empty; `.duplicate` → `flash(existing)`; `.shelfFull` → `showFull()`. Never copy/move original (store only a bookmark, spec §14/§24); `dropExited` clears `isDragOver`.

### 7.2 Drag-over visuals *(spec §27)*
- Target slot stronger border + subtle fill; whole-shelf accent on `isDragOver`. Subtle, native, no loud colors.
- **Done when:** drag from Finder → icon appears, `shelf.json` updated, survives relaunch; dup flashes; >8 shows "Shelf is full".

---

## Phase 8 — Plus button (NSOpenPanel)
*(spec §11)*
### 8.1
- Plus → `NSOpenPanel` (`canChooseFiles`, `canChooseDirectories`, `allowsMultipleSelection` = true; apps selectable as bundles; no `allowedContentTypes`). Call `NSApp.activate(ignoringOtherApps:true)` first (panel is non-activating). OK → `store.addMany(urls:startingAt:thisSlot)`; overflow → `showFull()`.
- **Done when:** plus → picker → file+folder+app appear with correct icons.

---

## Phase 9 — Opening items
*(spec §12, §12.1)*
### 9.1
- Tap occupied non-broken slot → `resolvedURL` then `BookmarkResolver.withAccess(url){ NSWorkspace.shared.open($0) }` (handles file→default app, folder→Finder, app→launch, .md→editor). Do not remove on open. Broken tap → no-op + log.
- **Done when:** each kind opens; item stays in shelf.

---

## Phase 10 — Drag OUT of the shelf
*(spec §15, §40)*
### 10.1
- Occupied non-broken slots are a drag **source** providing the real file URL: `.onDrag { NSItemProvider(contentsOf: resolvedURL) ?? NSItemProvider(object: resolvedURL as NSURL) }` (file representation preferred for upload controls / sandboxed targets; verify a real file lands in Finder). Keep `withAccess` open for the drag. Item stays after drag-out. Broken → `.onDrag` disabled.
- **Gesture disambiguation:** tap = open; drag from occupied slot = drag-out/rearrange source; drop onto slot = add/swap (internal vs external distinguished in Phase 11 by a private payload type).
- **Done when:** dragging a shelf item into Finder places the real file; shelf keeps the item.

---

## Phase 11 — Rearranging (swap)
*(spec §16)*
### 11.1
- Slot drag also offers an `NSItemProvider` of a private `UTType` (`"com.notchshelf.slot"`) carrying the source slot index (alongside the fileURL for drag-out).
- `DropDelegate.performDrop`: private-type present → **internal swap** `store.swap(source, target)` (swap chosen, spec §16), animate, persist; absent → external add (Phase 7). 
- **Done when:** drag A onto B swaps; order persists; drag-OUT to Finder still works.

---

## Phase 12 — Removing
*(spec §17, §24)*
### 12.1
- Minus → `store.remove(slot:)` (drops reference + bookmark; never deletes original/generated file). Animate slot back to empty. Minus hit area isolated from open gesture.
- **Done when:** minus empties slot, file remains on disk, `shelf.json` updated.

---

## Phase 13 — Clipboard → Markdown
*(spec §18, §39)*
### 13.1 `ClipboardMarkdownService.swift`
- `@MainActor enum ClipboardMarkdownService`: `makeNote(addingTo store:) -> Result<Int, ClipboardError>` (`.empty/.unsupported/.noSlot/.writeFailed`).
- Read `NSPasteboard.general.string(forType:.string)`; nil/empty → `.empty`. Filename `Clipboard Note YYYY-MM-DD HH-mm.md` (`DateFormatter`, `en_US_POSIX`); dedupe ` 1`, ` 2`… in `clipboardNotesDir`. Write UTF-8, preserve line breaks, atomic; failure → `.writeFailed`. Then `store.add(url:kind:.markdownNote)`; full → `.noSlot`.
- Note behaves like any item (real file + bookmark); only `kind` differs.
- **Done when:** copy text → trigger (Phase 14) → `.md` in `Clipboard Notes/`, appears in slot, opens.

---

## Phase 14 — Menu-bar menu
*(spec §21, §23)*
### 14.1
- Replace stub menu (spec §21): **Show Shelf** (show+expand), **Hide Shelf** (collapse+hide), **Clear Shelf** (`store.clear()`, keeps files — spec §23), **Paste Clipboard as Markdown** (`ClipboardMarkdownService.makeNote`; quiet log/optional small `NSAlert` on empty), separator, **Quit**. Status button icon `tray.full`.
- **Done when:** every item works.

---

## Phase 15 — Context menu & Reveal in Finder
*(spec §29, §30)*
### 15.1
- Occupied slot `.contextMenu`: **Open**; **Reveal in Finder** (`NSWorkspace.shared.activateFileViewerSelecting([url])`); **Copy Path** (`NSPasteboard` setString path); **Remove from Shelf**. Broken item → only Remove.
- **Done when:** all four work via right-click.

---

## Phase 16 — Resilience / broken items
*(spec §25, §33, §44)*
### 16.1
- Lazy-resolve in `SlotView` per appearance; nil → broken state (warning icon, dimmed, label kept; tap no-op; `.onDrag` off; context menu Remove only). Keep in slot.
- Audit every external-input path for no-crash: missing/moved/deleted file, empty/unsupported clipboard, full shelf, unsupported drag data, corrupt `shelf.json`. Each → graceful log, no `fatalError`/force-unwrap.
- **Done when:** add file → move/delete on disk → relaunch → broken state, removable, stable.

---

## Phase 17 — First-launch & polish
*(spec §27, §34, §42, §43)*
### 17.1
- Empty-state hint present + auto-hides after first item. Accessibility labels verified. Idle is event-driven only — no continuous polling (only one-shot collapse debounce + transient toasts). Visual pass vs spec §27 (dark blur, large radius, flat top hugging notch, soft shadow, subtle borders, quiet drag-over).
- **Done when:** polished, no console errors, low idle CPU.

---

## Phase 18 — Final verification (acceptance)
*(spec §36, §46)* — clean build, then walk:
1. Launch → menu-bar icon, no Dock icon, no window.
2. Cursor to notch → smooth grow-down; leave → collapse ~350ms.
3. Drag file from Finder toward notch → expands mid-drag → drop → native icon.
4. Plus → NSOpenPanel → file/folder/app → correct icons.
5. Click items → file/folder/app open correctly.
6. Drag item from shelf into Finder → real file lands; item stays.
7. Drag slot→slot → swap; persists after relaunch.
8. Minus → gone, original file on disk.
9. Copy text, Paste Clipboard as Markdown → `.md` in `…/NotchShelf/Clipboard Notes/`, in slot, opens.
10. Quit & relaunch → items + order restored; move/delete source → broken, removable, no crash.
11. Clear Shelf → empties, files remain.

---

## File manifest (all in `notchActions/`, auto-included via synchronized group)
| File | Phase | Role |
|---|---|---|
| `notchActionsApp.swift` (rewrite) | 0 | App entry, delegate adaptor |
| `AppController.swift` | 0/14 | Delegate, status item, menu, lifecycle (§37.1) |
| `Log.swift` | 1 | os.Logger categories (§35) |
| `AppPaths.swift` | 2 | Storage dirs |
| `ShelfItem.swift` | 2 | Model (§37.4) |
| `BookmarkResolver.swift` | 2 | Bookmarks + scoped access + classify (§25) |
| `ShelfStore.swift` | 2 | Persistence + slot ops (§37.5) |
| `IconProvider.swift` | 3 | Native icons (§37.8) |
| `NotchGeometry.swift` | 4 | Notch detection + frames (§5/§37.2) |
| `ShelfPanel.swift` | 4 | NSPanel (§7) |
| `ShelfWindowController.swift` | 4 | Panel lifecycle/positioning (§37.2) |
| `ShelfUIState.swift` | 5 | UI state |
| `VisualEffectBackground.swift` | 5 | Blur material |
| `ShelfView.swift` | 5 | Root shelf UI (§37.3) |
| `SlotView.swift` | 5 | Slot rendering + gestures (§10/§41) |
| `DragDropManager.swift` *(optional)* | 7/10/11 | Shared drag/drop helpers + private UTType (§37.6) |
| `ClipboardMarkdownService.swift` | 13 | Clipboard→md (§37.7) |

`PreviewProvider` (hover preview, §20/§37.9) is deferred — not in MVP.

## Non-goals for MVP (defer, spec §45)
Preferences window, Quick Look/hover preview, HTML→MD, multi-row/paging, live multi-display switching, global shortcuts, login item, auto-update, sandbox/App-Store polish.

## Suggestions (NOT in the MVP build — only if explicitly approved)
- `NSFilePromiseProvider` for the most robust drag-out.
- Login item via `SMAppService`.
- "Locate…" relink for broken items.
- Listed for future work; do NOT build unless told.
