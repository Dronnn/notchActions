# Technical Specification: macOS Notch Shelf App

## 1. Project Overview

Build a native macOS utility app that turns the MacBook display notch area into an interactive, persistent, animated shelf.

The app should use the area around the MacBook notch as a hidden interaction zone. When the user moves the mouse to the notch area, drags files toward it, or clicks/activates it, a smooth panel should expand downward from the notch.

The main idea is similar to a macOS “Dynamic Island”, but focused on productivity.

The app should work as:

- a persistent shelf for files, folders, and applications
- a drag-and-drop temporary transfer area
- a small launcher for frequently used files, folders, and apps
- a clipboard-to-Markdown utility
- a visually polished notch-based panel

The shelf should appear visually attached to the notch. It should not look like a normal floating window placed randomly at the top of the screen.

The app should feel native, fast, minimal, and polished.

Reference-style apps and concepts:

- NotchNook
- NotchDrop
- DropNotch
- NotchShelf
- NotchBox
- Moody
- macOS Dock icons
- Finder file icons
- iPhone Dynamic Island animation style

Do not clone any existing app directly. Use them only as general inspiration for interaction and visual direction.

---

## 2. Platform and Technology

Target platform:

- macOS

Preferred implementation:

- Swift
- AppKit for window management, drag and drop, menu bar behavior, screen detection, and system integration
- SwiftUI is acceptable for rendering the shelf UI if it works well inside an AppKit window or `NSPanel`
- no Electron
- no web app
- no server dependency
- the app should work offline

The app should be a native macOS menu bar utility.

---

## 3. Main User Scenarios

### 3.1 Drag a file into the notch shelf and move it somewhere else

1. The user drags a file from Desktop or Finder toward the MacBook notch.
2. The notch shelf expands smoothly from the notch area.
3. The user drops the file into an empty slot in the shelf.
4. The file appears as an icon inside one of the shelf slots.
5. The user switches to another Finder folder, another app, another Space, or another window.
6. The user opens the notch shelf again.
7. The user drags the file from the shelf into the new location or app.
8. The file behaves like a normal Finder file during drag and drop.

### 3.2 Add persistent files, folders, and apps manually

1. The user opens the shelf.
2. The user clicks an empty plus slot.
3. A native file picker opens.
4. The user selects files, folders, or applications.
5. Selected items appear in the shelf.
6. These items remain there after app restart, app quit, and macOS restart.
7. The user clicks an item to open it.

### 3.3 Create a Markdown file from clipboard content

1. The user copies text to the clipboard.
2. The user opens the shelf.
3. The user triggers a “Paste from Clipboard” action.
4. The app creates a Markdown file from the clipboard content.
5. The new Markdown file appears as an item in the shelf.
6. The user can open, drag, rearrange, or remove this item like any other shelf item.

---

## 4. Core Concept

The app should create an interactive shelf around the MacBook notch.

The shelf has two main states:

### 4.1 Collapsed State

In the collapsed state:

- the panel is invisible or almost invisible
- optionally, a tiny top-center trigger/tab can be visible
- the shelf should not distract the user
- it should not cover normal screen content
- it should not behave like a normal open window

### 4.2 Expanded State

In the expanded state:

- the panel appears below and around the notch
- it expands smoothly downward
- it shows predefined item slots
- empty slots show plus buttons
- occupied slots show icons for files, folders, apps, or generated Markdown notes
- the user can add, open, drag, rearrange, preview, and remove items

---

## 5. Notch Detection and Panel Placement

The app should position the shelf around the top center of the active display.

### 5.1 On MacBooks with a physical notch

The app should align the shelf with the real notch area.

Expected behavior:

- the collapsed trigger area is centered on the notch
- the expanded panel appears visually connected to the notch
- the notch looks like the top anchor of the panel
- the panel extends left, right, and downward from the notch

### 5.2 On Macs without a notch

The app should still work.

Fallback behavior:

- create a virtual notch at the top center of the active display
- optionally render a small black rounded tab at the top center
- the shelf should expand from this virtual notch area

### 5.3 Multiple displays

The app should handle multiple displays.

Expected behavior:

- if the cursor is on a built-in MacBook screen with a notch, use that notch
- if the cursor is on an external display, use the top center of that display as a virtual notch
- the shelf should appear on the display where the interaction happens
- if this is difficult for the first version, use the main display first, but structure the code so multi-display support can be added later

---

## 6. Panel Size and Shape

The shelf should be visually compact but large enough to contain icons and controls.

Initial size target:

- width: approximately 360-520 points
- height: approximately 120-180 points
- the panel should extend roughly 3 cm left, 3 cm right, and 3 cm downward from the notch area
- exact size should be adaptive, because macOS uses points, display scale factors, and different screen sizes

The panel should have:

- rounded rectangle or capsule-like shape
- large corner radius
- dark translucent material
- blur or visual effect material if possible
- subtle shadow
- native macOS look
- smooth shape and animation
- enough padding around icons
- no title bar
- no standard window border
- no traffic-light window buttons

The shelf should look like it belongs to the notch.

It should not look like a normal rectangular popover or ordinary utility window.

---

## 7. Window Behavior

Use an AppKit window or panel.

Possible implementation:

- `NSPanel`
- borderless `NSWindow`
- transparent background
- floating window level
- non-activating panel if possible
- custom content view
- AppKit + SwiftUI hybrid is acceptable

Window requirements:

- no title bar
- no close/minimize/zoom buttons
- transparent background outside the shelf shape
- appears above normal app windows
- should not steal focus during simple hover
- should accept drag and drop reliably
- should remain responsive when dragging files
- should not flicker
- should hide when not needed
- should collapse smoothly

The app should behave like a menu bar utility, not like a normal document-based app.

---

## 8. Activation Behavior

The shelf should expand in these cases.

### 8.1 Hover activation

When the user moves the mouse to the notch/top-center trigger area:

- the shelf expands
- the animation starts smoothly
- the shelf remains open while the cursor is inside the shelf
- when the cursor leaves, the shelf collapses after a short delay

There should be a small hide delay, for example 250-500 ms, to prevent flickering.

### 8.2 Drag activation

When the user drags files, folders, apps, or other supported content toward the notch/top-center area:

- the shelf should expand automatically
- it should visually highlight as a drop target
- the user should be able to drop items into empty slots
- the shelf should not disappear during drag operation

This is very important.

The shelf must be usable as a drag-and-drop target without requiring a click first.

### 8.3 Click activation

Optional but useful:

- clicking the notch trigger area should toggle the shelf
- clicking outside the shelf should collapse it
- this behavior can be configurable later

---

## 9. Animation Requirements

Animations should be smooth and polished.

Required animation states:

- collapsed to expanded
- expanded to collapsed
- drag-over highlight
- slot hover
- item rearranging
- item adding
- item removing
- optional preview appearance

Animation style:

- spring-like or ease-out animation
- no abrupt frame changes
- no flickering
- no jumpy resizing
- no sharp opacity changes
- should feel close to iPhone Dynamic Island behavior, but adapted to macOS

Recommended animation properties:

- opacity
- scale
- height
- y-position
- corner radius if needed
- background material opacity
- shadow opacity
- item icon scale on hover

The panel should appear to grow downward from the notch.

---

## 10. Shelf Layout

Inside the expanded panel, show predefined positions for items.

The layout should look like a prepared shelf with empty slots.

### 10.1 Slot design

Each slot should be a rounded square or rounded rectangle.

Each slot can be either:

- empty
- occupied

### 10.2 Empty slot

An empty slot should show:

- a centered plus button
- visible border around the slot
- subtle hover effect
- clear indication that the user can add something

The plus button should not be just a plain text symbol. It should look like a proper UI control inside a prepared empty place.

### 10.3 Occupied slot

An occupied slot should show:

- file icon, folder icon, app icon, or generated Markdown file icon
- optional item name if there is enough space
- hover state
- minus/remove button in the top-right corner
- optional preview on hover

The occupied slot should look similar to Finder or Dock item presentation.

Icons must be clear, high-quality, and properly scaled.

### 10.4 Number of slots

For the first version, use a fixed number of slots.

Suggested MVP:

- 6 to 10 slots

Good initial option:

- 8 slots in one horizontal row

The layout should be prepared for future expansion.

If the shelf has more items than visible slots later, possible future options:

- horizontal scrolling
- second row
- larger panel size
- pages

For MVP, a fixed row with a limited number of slots is acceptable.

---

## 11. Adding Items with Plus Button

When the user clicks the plus button in an empty slot:

- open a native macOS Open Panel
- allow selecting files
- allow selecting folders
- allow selecting applications
- allow multiple selection
- add selected items to the shelf

Use `NSOpenPanel`.

Open Panel requirements:

- can choose files: yes
- can choose directories: yes
- allows multiple selection: yes
- can choose applications: yes, because applications are bundles/directories on macOS
- should not restrict file types in MVP

After selection:

- selected items are added to available shelf slots
- if the user selected more items than available empty slots, add as many as possible and handle the rest gracefully
- do not crash
- optionally show a message or ignore overflow for MVP

If the plus button belongs to a specific empty slot:

- the first selected item should go into that slot
- additional selected items should go into the next available slots

---

## 12. Opening Items

When the user clicks an occupied item:

- if it is a file, open it with the default macOS app
- if it is a folder, open it in Finder
- if it is an application, launch the application
- if it is a generated Markdown file, open it with the default Markdown/text editor

Use native macOS APIs.

Recommended:

- `NSWorkspace.shared.open(...)`
- Launch Services where needed

Clicking an item should execute/open it.

Do not remove the item from the shelf after opening.

Items are persistent unless the user explicitly removes them.

---

## 12.1 Folder Behavior

Folders are a first-class supported item type.

The user must be able to:

- add a folder to the shelf using the plus button and native Open Panel
- drag a folder from Finder or Desktop into the shelf
- see a native macOS folder icon in the shelf
- click the folder item in the shelf
- open that folder in a new Finder window
- drag the folder item from the shelf back into Finder or another app
- rearrange the folder item between shelf slots
- remove the folder from the shelf without deleting the actual folder from disk

When the user clicks a folder item, the app should open that folder in Finder.

Recommended behavior:

- use `NSWorkspace.shared.open(folderURL)` for normal opening
- or use `NSWorkspace.shared.activateFileViewerSelecting([folderURL])` if the desired behavior is to reveal/select the folder in Finder

For this app, the primary expected behavior is:

- clicking a folder opens the folder itself in Finder

The folder must remain in the shelf after opening.

---

## 13. Persistence

This shelf is persistent.

Added items must stay in the shelf after:

- app restart
- app quit
- macOS restart

The app must save:

- item order
- item type
- file URL or bookmark
- display name
- optional icon cache if needed
- slot position

Use persistent storage.

Possible storage:

- `UserDefaults` for simple metadata
- local JSON file
- lightweight local database
- security-scoped bookmarks for file access

Important:

If the app is sandboxed, use security-scoped bookmarks.

If the app is not sandboxed, direct file URLs may work, but bookmark-based persistence is still preferred because files may move or require permission.

The shelf should not duplicate or copy selected files by default.

It should store references/bookmarks to the original files.

Exception:

- generated Markdown files from clipboard should be created and stored inside the app's local storage folder

---

## 14. Drag and Drop Into the Shelf

The shelf must accept drag and drop.

Supported input:

- files from Finder
- files from Desktop
- folders
- applications
- possibly URLs later
- possibly text later

When the user drags supported items toward the notch:

- the shelf expands automatically
- empty slots highlight
- the whole shelf can highlight as a valid drop target
- dropping an item adds it to the shelf

Drop behavior:

- if the user drops onto an empty slot, put item there
- if the user drops onto an occupied slot, either reject, swap, or insert depending on implementation
- for MVP, simplest behavior is acceptable, but it must be predictable
- multiple dragged items should be supported
- item order should follow drag order if possible

The app must not copy or move the original file when adding it to the shelf.

Adding to shelf means storing a reference/bookmark.

---

## 15. Drag and Drop Out of the Shelf

The user must be able to drag items from the shelf into:

- Finder
- Desktop
- another app that accepts dragged files
- another folder
- file upload controls if macOS drag and drop supports it

This is a core requirement.

Dragging an item out of the shelf should behave like dragging a real file from Finder.

Important:

- dragging out should not remove the item from the shelf automatically
- the item remains in the shelf unless the user removes it
- the drag operation should provide the original file URL through the pasteboard
- folders and applications should also be draggable if possible

---

## 16. Rearranging Items Inside the Shelf

The user must be able to rearrange items inside the shelf.

Behavior:

- drag an item from one slot to another slot
- if target slot is empty, move item there
- if target slot is occupied, swap items or insert item and shift others
- preserve the new order after app restart
- animate rearranging smoothly

For MVP, swapping is acceptable and simpler.

Example:

- slot 1 contains app A
- slot 2 contains file B
- user drags app A onto slot 2
- app A and file B swap places

Alternative behavior:

- drag item between slots and shift other items

Choose one behavior and implement it consistently.

---

## 17. Removing Items

Each occupied slot should have a small minus button in the top-right corner.

When the user hovers over an item:

- show the minus button
- the minus button should be visible enough but not too distracting

When the user clicks the minus button:

- remove the item from the shelf
- remove the saved reference/bookmark
- update persistent storage
- do not delete the original file from disk
- do not move the original file to Trash

This is only “remove from shelf”, not “delete file”.

Optional:

- add context menu with:
  - Open
  - Reveal in Finder
  - Remove from Shelf

---

## 18. Clipboard to Markdown File

The shelf should support creating a Markdown file from current clipboard content.

This feature can be implemented as a shelf action.

Possible UI options:

- a special clipboard slot
- a context menu action
- a button inside the shelf
- keyboard shortcut later

Required MVP behavior:

1. User copies text to the clipboard.
2. User opens the shelf.
3. User chooses “Paste from Clipboard” or clicks a clipboard-related action.
4. The app reads the current clipboard text.
5. The app creates a `.md` file from that text.
6. The generated Markdown file is stored inside the app's local storage folder.
7. The generated file is added to an empty shelf slot.

For first version:

- support plain text clipboard content
- save it as Markdown without complex conversion
- use `.md` extension
- preserve line breaks
- use UTF-8

Optional later:

- support rich text
- support HTML-to-Markdown conversion
- support image clipboard content
- support URL clipboard content

Generated file naming:

Use automatic readable names.

Examples:

- `Clipboard Note 2026-05-31 14-30.md`
- `Clipboard Note 1.md`
- `Clipboard Note 2.md`

If a file name already exists, generate a unique name.

Generated Markdown files should behave like normal shelf items:

- can be opened
- can be dragged out
- can be removed from shelf
- can be rearranged
- persists after restart

Removing from shelf should not necessarily delete the generated file.

---

## 19. Icon Appearance

Icons should look native.

Requirements:

- file icons should look like Finder file icons
- folder icons should look like Finder folder icons
- application icons should look like Dock or Finder app icons
- use system-provided icons where possible
- icons should be high-resolution
- icons should not look blurry
- icons should be scaled correctly
- do not use custom generic icons if macOS can provide real icons

Recommended API:

- `NSWorkspace.shared.icon(forFile:)`
- `NSWorkspace.shared.icon(forFileType:)`
- other AppKit icon APIs where appropriate

Icon layout:

- icon centered in slot
- enough padding
- maybe small label below icon if space allows
- label should be truncated if too long
- do not make the UI visually noisy

---

## 20. Hover Preview

If possible, show a small floating preview when the user hovers over an item.

This feature is optional for the first MVP, but the architecture should allow adding it later.

Preview behavior:

- appears after a short hover delay
- appears near the bottom of the shelf
- should not cover the item itself too much
- should not block interaction
- disappears when the mouse leaves the item
- disappears when the shelf collapses
- should look like a small native floating popover
- should be subtle and fast

Preview content by item type:

### 20.1 Image files

Show:

- image thumbnail
- file name
- file size if easy

### 20.2 Text and Markdown files

Show:

- first several lines of text
- file name
- maybe file size

### 20.3 Folders

Show:

- folder icon
- folder name
- basic info if easy

### 20.4 Applications

Show:

- app icon
- app name
- bundle identifier if easy

### 20.5 Unsupported files

Show:

- icon
- file name
- file type
- file size

Possible implementation:

- custom preview popover
- Quick Look integration later
- `QLThumbnailGenerator` for thumbnails if useful

Do not overcomplicate this feature in MVP.

---

## 21. Menu Bar App

The app should run as a macOS menu bar utility.

It should have a status bar icon.

Menu items:

- Show Shelf
- Hide Shelf
- Clear Shelf
- Paste Clipboard as Markdown
- Preferences
- Quit

Optional:

- Open at Login
- About
- Check for Updates if needed later

The app should not require a Dock icon unless needed.

Prefer `LSUIElement`-style behavior for a menu bar utility if appropriate.

---

## 22. Preferences

Preferences are optional for MVP but should be considered.

Possible settings:

### 22.1 General

- Launch at login
- Show Dock icon: yes/no
- Clear shelf on quit: yes/no

Default:

- clear shelf on quit should be off
- items should persist by default

### 22.2 Activation

- expand on hover
- expand on click
- expand on drag
- hide delay
- trigger area size

Default:

- hover enabled
- drag enabled
- click optional

### 22.3 Appearance

- panel size: small / medium / large
- icon size: small / medium / large
- number of slots
- show item names: yes/no
- use blur/material background: yes/no

### 22.4 Behavior

- open item on single click or double click
- remove confirmation: yes/no
- show preview on hover: yes/no

MVP can use fixed defaults without a full Preferences window, but the code should not make future preferences impossible.

---

## 23. Clear Shelf

The app should provide a “Clear Shelf” action.

Behavior:

- remove all items from the shelf
- clear saved references/bookmarks
- do not delete original files
- do not delete generated Markdown files unless explicitly designed that way

For generated Markdown files:

Recommended behavior:

- remove them from the shelf only
- keep the files in the app's local storage folder

Optional later:

- add setting to delete generated clipboard notes when removing them

---

## 24. File Handling Rules

Important rules:

- Adding a file to the shelf should not move it.
- Adding a file to the shelf should not copy it.
- Removing a file from the shelf should not delete it.
- Opening a file should not remove it.
- Dragging a file out of the shelf should not remove it.
- Rearranging items should only change shelf order.
- Generated Markdown files are real files created by the app.

The shelf stores references to user-selected items.

---

## 25. Security and Permissions

Consider sandboxing.

If sandboxed:

- use security-scoped bookmarks
- start and stop accessing security-scoped resources correctly
- store bookmark data persistently
- handle stale bookmarks

If not sandboxed:

- direct file URLs may work
- still prefer bookmarks for reliability

The app should handle permission errors gracefully.

Examples:

- file no longer exists
- bookmark is stale
- file moved
- app no longer has permission
- external drive disconnected

In such cases:

- show broken item state
- allow user to remove the item
- optionally allow user to relink the item later

---

## 26. Edge Cases

Handle these cases as well as reasonably possible:

- Mac without physical notch
- external display
- multiple displays
- macOS menu bar auto-hide
- fullscreen apps
- Stage Manager if relevant
- Spaces
- display scale factor changes
- connecting/disconnecting external displays
- files moved after being added
- files deleted after being added
- folders moved after being added
- applications moved or removed
- many files dragged at once
- all slots full
- duplicate items
- dragging while shelf wants to auto-hide
- dragging out while mouse leaves shelf bounds
- clipboard is empty
- clipboard contains unsupported data
- app restarted after files were added
- macOS restarted after files were added

For MVP, not every edge case needs a perfect UI, but the app should not crash.

---

## 27. Visual Design Direction

The visual style should be native, minimal, and polished.

Panel:

- dark translucent background
- blur/material if possible
- rounded shape
- soft shadow
- connected visually to the notch
- compact, not huge
- no unnecessary text
- no heavy borders

Slots:

- rounded square or rounded rectangle
- subtle border
- clear hover effect
- plus button in empty slots
- native-looking icons in occupied slots
- small minus button on hover

Drag-over state:

- highlight the whole shelf or target slot
- make it clear that dropping is possible
- avoid loud colors
- use subtle native macOS visual language

Preview:

- small floating panel
- subtle shadow
- dark or material background
- compact content

Overall feeling:

- like a macOS Dynamic Island
- like a small shelf hidden inside the notch
- not like a random toolbar
- not like a normal app window

---

## 28. Keyboard Shortcuts

Add basic keyboard shortcut support if it does not overcomplicate MVP.

Suggested shortcuts:

- show/hide shelf
- paste clipboard as Markdown
- clear shelf

For MVP, keyboard shortcuts can be optional.

If implemented, shortcuts should be configurable later.

Important:

- do not use shortcuts that conflict with common macOS shortcuts
- global shortcuts may require additional permissions or event monitoring
- local shortcuts inside the app are simpler

---

## 29. Context Menu

Occupied items should optionally support a right-click context menu.

Menu items:

- Open
- Reveal in Finder
- Copy Path
- Remove from Shelf

For generated Markdown files:

- Open
- Reveal in Finder
- Copy Path
- Remove from Shelf

This is useful because the minus button may be too small for some users.

For MVP, this is recommended but not strictly required.

---

## 30. Reveal in Finder

The app should provide a way to reveal an item in Finder.

This can be implemented through:

- context menu
- menu bar action
- optional modifier-click behavior

Recommended API:

- `NSWorkspace.shared.activateFileViewerSelecting(...)`

This is useful for files, folders, apps, and generated Markdown files.

---

## 31. Duplicate Items

The app should handle duplicate items predictably.

Recommended MVP behavior:

- allow duplicates only if they are in different slots, or
- reject duplicates and focus/highlight the already existing item

Choose one behavior and keep it consistent.

Recommended first version:

- reject duplicates
- if the item already exists in the shelf, briefly highlight the existing slot

This prevents confusion.

---

## 32. Full Slots Behavior

If all slots are full and the user tries to add more items:

- do not crash
- do not silently lose data without feedback
- show a small non-intrusive message, tooltip, or temporary text such as “Shelf is full”
- for drag and drop, visually indicate that the shelf cannot accept more items

For MVP:

- fixed number of slots is acceptable
- no need to implement scrolling immediately

---

## 33. Item State: Missing or Broken Files

If a stored file cannot be resolved:

- show a broken or warning state
- keep the item in its slot
- allow the user to remove it
- optionally allow the user to relink it later

Broken item behavior:

- clicking it should not crash
- dragging it out should be disabled or should fail gracefully
- context menu should still allow Remove from Shelf

---

## 34. First Launch Experience

On first launch, the app should make the basic behavior discoverable.

Minimal acceptable behavior:

- show an empty shelf with plus slots
- maybe show a short tooltip or small text: “Drag files here or press +”

Do not build a large onboarding flow for MVP.

The app should be understandable without instructions.

---

## 35. Logging and Debugging

Add basic internal logging for development.

Log important events:

- app launched
- shelf shown/hidden
- file added
- item opened
- item removed
- drag entered shelf
- drop completed
- bookmark resolved
- bookmark failed
- clipboard note created
- persistence save/load failed

Use simple logging.

Do not show technical logs to the user.

---

## 36. MVP Requirements

The first working version must include:

1. Native macOS menu bar app
2. Floating notch-aligned panel
3. Collapsed and expanded states
4. Hover to expand
5. Dragging files toward the notch expands the panel
6. Drag and drop files/folders/apps into shelf
7. Predefined empty slots with plus buttons
8. `NSOpenPanel` from plus button
9. Add files, folders, and apps
10. Show native icons
11. Click item to open/launch
12. Persistent storage after app restart
13. Drag items from shelf back into Finder or another app
14. Rearrange items between slots
15. Remove item using minus button
16. Paste clipboard text as generated Markdown file
17. Basic menu bar menu with Quit and Clear Shelf
18. Graceful behavior when slots are full
19. Basic broken-file handling
20. Reveal in Finder through context menu or another simple action

MVP does not need:

- full Preferences window
- perfect Quick Look preview
- complex HTML-to-Markdown conversion
- multi-row shelf
- cloud sync
- App Store sandbox polish
- automatic updates
- advanced file conflict management
- advanced onboarding
- custom themes

---

## 37. Suggested Architecture

Suggested components:

### 37.1 AppController

Responsible for:

- app startup
- menu bar item
- global coordination
- preferences
- shelf window lifecycle

### 37.2 ShelfWindowController

Responsible for:

- creating and positioning the floating panel/window
- tracking screen changes
- showing/hiding shelf
- collapsed/expanded animation
- window level and behavior

### 37.3 ShelfView / ShelfContentView

Responsible for:

- rendering slots
- plus buttons
- item icons
- remove buttons
- hover states
- drag/drop UI
- preview trigger

Can be SwiftUI or AppKit.

### 37.4 ShelfItem

Model representing one shelf item.

Fields:

- id
- slotIndex
- type: file / folder / application / markdownNote
- displayName
- fileURL or bookmarkData
- createdAt
- updatedAt
- maybe cachedIconIdentifier

### 37.5 ShelfStore

Responsible for:

- saving items
- loading items
- persisting order
- updating item positions
- removing items
- storing bookmark data
- resolving bookmark data

### 37.6 DragDropManager

Responsible for:

- accepting external dragged files
- starting drag from shelf to other apps
- internal rearranging
- pasteboard integration

### 37.7 ClipboardMarkdownService

Responsible for:

- reading clipboard content
- creating Markdown files
- generating file names
- storing generated files
- returning a `ShelfItem`

### 37.8 IconProvider

Responsible for:

- getting native icons for files/folders/apps
- scaling icons
- caching icons if needed

### 37.9 PreviewProvider

Optional for MVP.

Responsible for:

- creating lightweight previews
- reading text previews
- generating thumbnails
- showing preview popover

---

## 38. Data Model Example

Example logical model:

```swift
struct ShelfItem: Identifiable, Codable {
    let id: UUID
    var slotIndex: Int
    var kind: ShelfItemKind
    var displayName: String
    var bookmarkData: Data?
    var originalURLString: String?
    var createdAt: Date
    var updatedAt: Date
}

enum ShelfItemKind: String, Codable {
    case file
    case folder
    case application
    case markdownNote
}
```

Shelf layout:

- fixed number of slots
- each slot can contain zero or one item
- slot index determines visual order

Persistence:

- save array of `ShelfItem` records
- preserve `slotIndex`
- restore items on app launch
- if bookmark cannot be resolved, show broken item state

---

## 39. Generated Markdown Files

Generated Markdown files should be stored in the app's local storage directory.

Possible location:

- Application Support / NotchShelf / Clipboard Notes

File content:

- use current clipboard plain text
- save as UTF-8
- extension: `.md`

Generated file name examples:

- `Clipboard Note 2026-05-31 14-30.md`
- `Clipboard Note 2026-05-31 14-30-01.md`
- `Clipboard Note 1.md`

If a file name already exists, generate a unique name.

Generated Markdown files should behave like normal shelf items:

- can be opened
- can be dragged out
- can be removed from shelf
- can be rearranged
- persists after restart

Removing from shelf should not necessarily delete the generated file.

---

## 40. Drag and Drop Technical Details

External drag into shelf:

- accept file URLs from pasteboard
- support multiple file URLs
- detect folders and applications
- create shelf items from dropped URLs
- store bookmarks

Internal drag inside shelf:

- drag item from slot to slot
- update slotIndex
- persist new order
- animate movement

Drag out from shelf:

- write file URL to pasteboard
- make the drag operation compatible with Finder
- original file should be used, not a copy if possible
- generated Markdown file should also be draggable as a real file

Do not implement fake dragging that only works inside the app.

The drag should work with Finder and normal macOS apps.

---

## 41. Interaction Details

### 41.1 Empty slot hover

- slightly brighten border
- maybe scale plus icon slightly
- cursor should indicate clickable area if possible

### 41.2 Occupied slot hover

- slightly highlight background
- show minus button
- optionally show item name
- optionally start hover preview timer

### 41.3 Drag over empty slot

- stronger highlight
- slot should look ready to accept the item

### 41.4 Drag over occupied slot

- show whether item will be swapped or inserted
- behavior must be visually clear

### 41.5 Remove button

- small minus button in top-right corner
- should not accidentally trigger item open
- should be easy enough to click

### 41.6 Clicking occupied item

- open/launch the item
- do not remove it
- do not rearrange it

---

## 42. Performance Requirements

The app should be lightweight.

Requirements:

- low idle CPU usage
- no constant heavy polling if avoidable
- animations should be smooth
- icon loading should not freeze UI
- large files should not be loaded fully just to show icons
- previews should be lazy
- clipboard should be read only when needed

The app should not slow down normal macOS usage.

---

## 43. Accessibility and Usability

Basic accessibility should be considered.

Requirements:

- buttons should have accessibility labels
- plus buttons should be identifiable
- remove buttons should be identifiable
- item slots should expose item names
- keyboard navigation is optional for MVP but useful later

Example labels:

- Add item
- Open item
- Remove item from shelf
- Paste clipboard as Markdown
- Clear shelf

---

## 44. Error Handling

The app should not crash in normal failure cases.

Handle:

- selected file cannot be accessed
- bookmark cannot be resolved
- file was deleted
- folder was moved
- app was removed
- clipboard is empty
- clipboard does not contain text
- no empty slots available
- drag data is unsupported
- generated Markdown file cannot be created

User-facing errors can be minimal for MVP.

Example:

- show disabled/broken item state
- show small alert only when needed
- log technical details for debugging

---

## 45. Non-Goals for MVP

Do not implement these in the first version unless everything else is done:

- cloud sync
- account system
- collaboration
- complex tagging
- nested folders inside shelf
- unlimited items
- AI features
- file search indexing
- custom icon editor
- full Quick Look replacement
- advanced clipboard history
- App Store payment logic
- plugin system

Keep the first version focused.

---

## 46. Expected Final Result

The final result should be a native macOS app where the user can use the notch as a persistent shelf.

Expected behavior:

- the user moves the mouse to the notch
- the shelf expands smoothly
- empty slots with plus buttons are visible
- the user can add files, folders, apps, and Markdown notes
- items look like Finder/Dock icons
- items remain after restart
- clicking an item opens it
- dragging an item out works like dragging a real Finder file
- dragging items inside the shelf rearranges them
- pressing minus removes an item from the shelf
- copying text and pasting it into the shelf creates a Markdown file
- the app feels native, polished, and useful

The shelf should feel like it belongs to the MacBook notch.

The most important qualities:

- reliable drag and drop
- persistent items
- native macOS behavior
- smooth animation
- clean visual design
- clear slot-based layout
