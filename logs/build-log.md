# Build Log: notchActions MVP

Detailed, as-it-happens log of the build. Plan: `docs/plan.md`. Spec: `docs/specs.md`. Progress tracker: `docs/build-progress.md`.

## Setup (2026-05-31)
- Read `docs/plan.md` and `docs/specs.md` in full.
- Resolved a conflict between plan and project conventions: the model layer (`ShelfStore`, `ShelfUIState`) will use the `@Observable` macro + `@MainActor` (project CLAUDE.md mandates `@Observable`; plan's `ObservableObject` snippets are treated as skeleton). Views hold them as plain `let` properties; Observation tracks property access in `body`.
- Verification approach: keep builds green after every phase via Xcode MCP `BuildProject`; launch the app on the real notched MacBook at visual milestones (Phase 5, 6, 17, 18) for hardware confirmation.
- Created `docs/build-progress.md` (phase checklist). Left canonical `docs/plan.md` untouched.

## Phase 0 — Project surgery & app shell (build green)
- Removed SwiftData template (`ContentView.swift`, `Item.swift`); rewrote the app entry as a menu-bar utility (`Settings { EmptyView() }` scene + `@NSApplicationDelegateAdaptor`).
- Added `AppController` (NSApplicationDelegate): `setActivationPolicy(.accessory)`, status item with `tray.full` SF Symbol, stub menu with only Quit (full menu in phase 14).
- pbxproj app-target edits (Debug + Release): `ENABLE_APP_SANDBOX` YES→NO, `MACOSX_DEPLOYMENT_TARGET` 15.6→14.0, added `INFOPLIST_KEY_LSUIElement = YES`. No entitlements file exists, so sandbox is off purely via the build setting.
- Build-tooling fixes needed to get a green build:
  - `ENABLE_USER_SCRIPT_SANDBOXING` YES→NO (project level) — the sandboxed Lint & Format phase couldn't read `.swiftformat`/`.swiftlint.yml` or write reformatted files. Build-only setting; no effect on the shipped app.
  - `.swiftformat` and `.swiftlint.yml` were unadapted CocoonWeaver copies: set the header template to a notchActions / Andreas Maier header (Xcode style) and repointed all `included`/`excluded`/`--exclude` paths to `notchActions`.
- Renamed the `@main` type `notchActionsApp` → `NotchActionsApp` (and its file) to satisfy SwiftLint `type_name` (error severity on lowercase types). App's user-facing name stays `notchActions` via `CFBundleDisplayName`/bundle id.
- Tooling notes: a format-on-save/edit hook plus the build's swiftformat both reformat files (attributes to prev-line, doc-comments, etc.); new source files are created via filesystem tools (per Andrew) since the Xcode MCP `XcodeWrite` mis-resolves single-level new-file paths to the repo root.
- `BuildProject`: green.

## Phase 1 — Logging (build green)
- Added `Log.swift`: `enum Log` with `os.Logger` per category (`lifecycle`, `dragdrop`, `persistence`, `clipboard`, `geometry`), subsystem = `Bundle.main.bundleIdentifier ?? "notchActions"`.
- Added `Log.lifecycle.info("notchActions launched")` in `applicationDidFinishLaunching`.
- Import notes: `Log.swift` needs `import Foundation` (for `Bundle`); any file calling `Log.x.info(...)` needs `import os` (the string-literal `OSLogMessage` initializer is defined in `os`).
- `BuildProject`: green.

## Phase 2 — Model, paths, bookmarks, store (build green)
- `AppPaths`: `supportDir` = Application Support/notchActions, `clipboardNotesDir`, `storeFile` (shelf.json). Modern Foundation (`URL.applicationSupportDirectory`, `appending(path:directoryHint:)`); creates dirs on demand, logs failures.
- `ShelfItem` + `ShelfItemKind` (spec §38). Kept `let id`/`let createdAt` (no defaults) so Codable decode restores them — using the synthesized memberwise init (avoids a custom 8-param init that would trip SwiftLint `function_parameter_count`).
- `BookmarkResolver`: `makeBookmark` (`.withSecurityScope`), `resolve` (logs + nil on failure), `classify` (.app→application, dir→folder, else file), `withAccess` (rethrows; a false scope-start does not block the body, per non-sandbox note §25).
- `ShelfStore` (`@MainActor @Observable`): slotCount 8, sparse `items`, queries (`item(at:)`, `firstEmptySlot`, `emptySlots`, `resolvedURL`, `contains`), mutations (`add`→AddResult, `addMany`, `remove`, `swap`, `clear`), persistence (atomic pretty JSON, ISO-8601 dates; `load` sanitizes to unique slots 0..<8 and tolerates missing/corrupt). Wired `store` into `AppController`.
- Decisions: dup check compares standardized `originalURLString` paths; `resolvedURL` requires the file to exist (so moved-away/deleted items surface as broken); `swap` with an empty target acts as a move.
- Fix: `items.count` inside a `Logger` interpolation (escaping autoclosure) required explicit self — captured the count in a local instead (tooling-proof vs swiftformat `redundantSelf`).
- `BuildProject`: green.
- Review milestone: launched a 4-dimension adversarial review workflow + an independent Codex CLI review on the data layer (results applied below once in).

## Phase 3 — Icons (build green)
- `IconProvider` (`@MainActor enum`): `icon(for:broken:size:)` → `NSWorkspace.shared.icon(forFile:)` sized; broken/nil → `exclamationmark.triangle` symbol. Small in-memory cache keyed `path-size`, cap 64 (clear-on-overflow; the shelf only ever holds a handful of icons). SwiftUI will wrap with `Image(nsImage:)` in phase 5.
- `BuildProject`: green.

## Phase 4 — Notch geometry & panel (partial; build green)
- Reordering note: plan §4.3 `ShelfWindowController` builds `NSHostingView(rootView: ShelfView(store:uiState:))`, which needs the Phase 5 types `ShelfView`/`ShelfUIState`. So 4.1 `NotchGeometry` + 4.2 `ShelfPanel` are built here; 4.3 is built right after Phase 5 to keep every build green.

## Data-layer review (workflow + Codex), outcomes
- Ran a 4-dimension adversarial review workflow (8 agents) + an independent Codex CLI (gpt-5.5) review. Triaged 7 distinct findings:
  - ACCEPTED: heal stale-but-resolvable bookmarks at launch (`healStaleBookmarks`, keeps `resolvedURL` pure/side-effect-free for SwiftUI); `swap` now bounds-checks slots and only saves on a real mutation; duplicate detection also compares resolved bookmark URLs (catches moved files); `addMany` fills forward from the clicked slot (5,6,7… not 5,0,1).
  - REJECTED (with reason): "fail add when bookmark creation fails" — intentional & spec-allowed fallback to `originalURLString` in a non-sandboxed app (§13/§25), failing would regress; "return/rollback save failures" — plan §2.4 + spec §44 mandate log-and-continue, rollback is over-engineering for MVP.
  - DEFERRED + documented: paths/names logged as `.public` aid Console-based milestone verification now; harden (mask user paths) before any release.
- Re-built green after the fixes.

## Phase 5 — Shelf UI + Phase 4.3 ShelfWindowController (build green; launched for visual check)
- `ShelfUIState` (@MainActor @Observable): isExpanded/isDragOver/hoveredSlot/highlightSlot/fullShelfToast; `flash()`/`showFull()` auto-clear after 1.2s via cancellable `Task` (no GCD).
- `VisualEffectBackground`: NSViewRepresentable over NSVisualEffectView (.hudWindow / .behindWindow / .active).
- `ShelfActions` (@MainActor enum): `addViaOpenPanel` (NSApp.activate → NSOpenPanel → addMany; flash dup / showFull overflow) and `open` (resolvedURL → withAccess → NSWorkspace). Keeps imperative AppKit out of the views.
- `SlotView` (+ private EmptySlotView/OccupiedSlotView): empty = filled plus control (hover brightens border + scales glyph); occupied = native icon + middle-truncated label + minus on hover (isolated hit area) + open Button; broken = dimmed, open disabled; dup-flash accent ring; §43 accessibility labels.
- `ShelfView` (+ ShelfPanelContent + FullShelfToast): UnevenRoundedRectangle (flat top, rounded bottom r22) over blur + black-0.35 overlay + soft shadow; subtle border, accent on drag-over; empty-state hint; full toast. Collapse/expand: height 0↔150 + opacity + scale 0.92 (anchor .top) + clip, spring(0.32, 0.82).
- `ShelfWindowController` (4.3): owns ShelfPanel + NSHostingView(ShelfView); positions to `expandedPanelRect` on NSScreen.main; observes didChangeScreenParameters; show/hide. Panel is always expanded-size (anti-flicker).
- `AppController`: added uiState + shelfWindowController; TEMP expanded show for this milestone (to be removed in Phase 6).
- Deviations from plan: slot size is fit-to-width (8 slots can't be 64pt in a 440 panel → ~46pt each); slot interactions (plus/open/remove) wired now since they're all slot behaviors. Drag/drop, clipboard, menu remain in later phases.
- BuildProject: green. Launched the Debug build for on-notch visual verification.

## Phase 18 — Final review + fixes + visual tuning (build green)
- Ran a final dual review: a 4-dimension adversarial workflow (18 agents) + an independent Codex CLI review of the interaction/window layer. Triaged and applied all confirmed findings:
  - CRITICAL: the always-on trigger was a bare NSPanel (hidesOnDeactivate defaults true) → it got ordered out whenever the accessory app deactivated, killing the only entry point. Set `triggerWindow.hidesOnDeactivate = false`.
  - HIGH: `•••` "Hide Shelf" only set `isExpanded=false`, leaving the invisible panel ordered-front and intercepting input → routed Hide through `ShelfWindowController.hide()` (orderOut) via an `onHide` closure threaded into the views.
  - MEDIUM: re-entering after collapse started didn't re-expand → panel `onMouseEntered` now calls `expand()`. Removed `.fullScreenAuxiliary` from both windows (locked decision: not over fullscreen apps). Added `draggingExited`/`draggingEnded` to MouseTrackingView so a drag that leaves without dropping reschedules collapse. Clipboard note now guards `firstEmptySlot` before writing the file (no orphan notes when full).
  - LOW: trigger reduced to exactly the notch (no downward lip) so it can't swallow clicks just below the notch; added `Log.dragdrop` lines on drop; marked `SlotDrag` static funcs `nonisolated` (called from off-main @Sendable drag closures).
- Visual tuning per Andrew's on-notch feedback: background to near-black (black overlay 0.35 → 0.85) so it reads as part of the notch; compact sizing (slot 90→78, gaps 12→8, padding 16→12) to reduce free space and pull the slots closer to the notch.
- Deferred (Andrew-requested, plan-deferred): hover content preview (§20).
- BuildProject: green. Relaunched; committed + pushed; README updated.

## Phases 7-17 — interactions, clipboard, menus, context menu, resilience (build green)
- Phase 7/10/11 (one mechanism): `SlotDrag` private in-process payload tags a drag with its source slot. `SlotView.onDrop` uses `SlotDropDelegate` — if the dragged provider carries `SlotDrag.typeID` it's an internal rearrange (`store.swap`), otherwise an external file add (`ShelfActions.dropFiles` loads URLs via async continuation → `store.addMany`). Occupied non-broken slots are a drag source: `NSItemProvider(contentsOf:)` (real file for Finder/other apps) + the private payload (`visibility: .ownProcess`). Drag-over highlight via `uiState.hoveredSlot`/`isDragOver` (the latter also suppresses collapse).
- Phase 13: `ClipboardMarkdownService` writes UTF-8 `.md` to `notchActions/Clipboard Notes` (`Clipboard Note yyyy-MM-dd HH-mm.md`, deduped), adds as `.markdownNote`. `ClipboardError` = empty/unsupported/noSlot/writeFailed.
- Phase 14: the menu lives in the shelf `•••` (`ShelfCenterControls`): Paste Clipboard as Markdown, Clear Shelf, Hide Shelf, Quit — the app's only control surface (no status item, per Andrew).
- Phase 15: `.contextMenu` on occupied slots → Open / Reveal in Finder (`activateFileViewerSelecting`) / Copy Path / Remove; broken → Remove only.
- Phase 16: broken items show a warning icon, dimmed, open + drag disabled, context menu Remove only. No-crash audited across corrupt `shelf.json`, empty/unsupported clipboard, full shelf, and unsupported drag data.
- Phase 17: empty-state hint (opacity, stable layout), accessibility labels (§43), event-driven idle only. Hover preview (§20) deferred per plan — flagged as Andrew's top follow-up.

## Layout rework + Phase 6 — Activation, and the "fully hidden" model (build green)
- Per Andrew's feedback, replaced the single row with a **2·4·2 U-shape** (`ShelfLayout`): top row = corner slots 0 & 6 with the notch-facing center open; bottom row = 1,2,3,4,5,7. Slots are now **~2× bigger** (90pt, fixed) and the panel size is derived from the layout. Hint + a `•••` control menu live in the open center; layout is stable (opacity, not insert/remove) so removing an item no longer shifts the row.
- `•••` menu (the app's only control surface): Hide Shelf, Clear Shelf, Quit. (Paste Clipboard added in Phase 13.)
- **Fully hidden app** (Andrew's requirement): removed the menu-bar status item and the forced show. `AppController` just creates the controller. The app has no dock icon and no status item.
- `MouseTrackingView`: transparent NSView reporting mouse enter/exit + file-drag entry via closures.
- `ShelfWindowController` (rebuilt): owns the shelf panel + an always-on transparent **notch trigger window** (sized to `collapsedTriggerRect` = notch + small downward lip, no horizontal widening so it never covers menu-bar items). Hover or file-drag entering the trigger → expand; cursor leaving the panel → 350ms debounced collapse (cancellable Task, suppressed while `isDragOver`); after the collapse animation the panel is ordered out so it stops covering the screen.
- `ShelfPanel.canBecomeKey` → true (non-activating, so hover never steals focus, but clicks/menus work).
- Config cleanup: removed invalid/renamed SwiftLint rules (`anyobject_protocol`, `inert_defer`, `unused_import`; renamed `operator_whitespace`→`function_name_whitespace`); set swiftformat `--varattributes same-line` to resolve the `attributes` rule conflict. (The red "Cannot find … in scope" errors Andrew saw were a stale SourceKit index on the iCloud-hosted synced group — build was green throughout.)
- BuildProject: green.


