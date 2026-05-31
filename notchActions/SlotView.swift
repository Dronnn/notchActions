//
//  SlotView.swift
//  notchActions
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import AppKit
import os
import SwiftUI
import UniformTypeIdentifiers

// MARK: - SlotView

/// one shelf slot: empty (plus control) or occupied (icon + label + remove), with hover, the
/// duplicate-flash ring, the drag-over highlight, and a hover preview (spec §10, §14, §16, §20, §41, §43).
struct SlotView: View {
    let index: Int
    let store: ShelfStore
    let uiState: ShelfUIState

    @State private var isHovering = false

    var body: some View {
        let item = store.item(at: index)
        let resolvedURLs = item.map { store.resolvedURLs(for: $0) } ?? []
        let primaryURL = resolvedURLs.first
        let broken = item != nil && resolvedURLs.isEmpty
        // any file in the bundle that fails to resolve makes Locate… available, even when others resolve.
        let hasBrokenFiles = item.map { resolvedURLs.count < $0.files.count } ?? false
        // true while any slot is being dragged, so no preview pops up and covers the shelf mid-drag.
        let isDragging = uiState.draggingSourceSlot != nil

        Group {
            if let item {
                OccupiedSlotView(
                    index: index,
                    item: item,
                    resolvedURLs: resolvedURLs,
                    primaryURL: primaryURL,
                    broken: broken,
                    hasBrokenFiles: hasBrokenFiles,
                    isHovering: isHovering,
                    isDragging: isDragging,
                    onOpen: { ShelfActions.open(item, store: store) },
                    onRemove: { store.remove(slot: index) },
                    onReveal: { ShelfActions.reveal(item, store: store) },
                    onCopyPath: { ShelfActions.copyPath(item, store: store) },
                    onCopy: { ShelfActions.copyToClipboard(item, store: store) },
                    onFill: { ShelfActions.fillFromClipboard(slot: index, store: store, uiState: uiState) },
                    onLocate: { ShelfActions.locate(item, store: store) },
                    resolveFile: { store.resolvedURL(for: $0) },
                    setPreviewing: { uiState.isPreviewing = $0 },
                    setDraggingSource: { uiState.draggingSourceSlot = $0 }
                )
            } else {
                EmptySlotView(
                    isHovering: isHovering,
                    onAdd: { ShelfActions.addViaOpenPanel(preferredSlot: index, store: store, uiState: uiState) },
                    onFill: { ShelfActions.fillFromClipboard(slot: index, store: store, uiState: uiState) }
                )
            }
        }
        .frame(width: ShelfLayout.slotSize, height: ShelfLayout.slotSize)
        .overlay {
            if uiState.hoveredSlot == index {
                RoundedRectangle(cornerRadius: ShelfLayout.slotCornerRadius, style: .continuous)
                    .fill(Color.accentColor.opacity(0.12))
                    .overlay {
                        RoundedRectangle(cornerRadius: ShelfLayout.slotCornerRadius, style: .continuous)
                            .strokeBorder(Color.accentColor.opacity(0.9), lineWidth: 2)
                    }
            }
        }
        .overlay {
            if uiState.highlightSlot == index {
                RoundedRectangle(cornerRadius: ShelfLayout.slotCornerRadius, style: .continuous)
                    .strokeBorder(Color.accentColor, lineWidth: 2)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isHovering)
        .animation(.easeInOut(duration: 0.15), value: uiState.hoveredSlot)
        .animation(.easeInOut(duration: 0.2), value: uiState.highlightSlot)
        .onHover { isHovering = $0 }
        .onDrop(of: [.fileURL], delegate: SlotDropDelegate(index: index, store: store, uiState: uiState))
    }
}

// MARK: - EmptySlotView

private struct EmptySlotView: View {
    let isHovering: Bool
    let onAdd: () -> Void
    let onFill: () -> Void

    var body: some View {
        Button(action: onAdd) {
            RoundedRectangle(cornerRadius: ShelfLayout.slotCornerRadius, style: .continuous)
                .fill(.white.opacity(isHovering ? 0.16 : 0.08))
                .overlay {
                    RoundedRectangle(cornerRadius: ShelfLayout.slotCornerRadius, style: .continuous)
                        .strokeBorder(.white.opacity(isHovering ? 0.6 : 0.32), lineWidth: 1)
                }
                .overlay {
                    Image(systemName: "plus")
                        .font(.title)
                        .foregroundStyle(.white.opacity(0.9))
                        .scaleEffect(isHovering ? 1.12 : 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add item")
        .contextMenu {
            Button("Fill from Clipboard") { onFill() }
            Button("Add File…") { onAdd() }
        }
    }
}

// MARK: - OccupiedSlotView

private struct OccupiedSlotView: View {
    let index: Int
    let item: ShelfItem
    let resolvedURLs: [URL]
    let primaryURL: URL?
    let broken: Bool
    let hasBrokenFiles: Bool
    let isHovering: Bool
    /// true while any slot drag is in flight; the preview hides for the whole drag so it never covers the
    /// slots below the dragged one.
    let isDragging: Bool
    let onOpen: () -> Void
    let onRemove: () -> Void
    let onReveal: () -> Void
    let onCopyPath: () -> Void
    let onCopy: () -> Void
    let onFill: () -> Void
    let onLocate: () -> Void
    let resolveFile: (ShelfFile) -> URL?
    let setPreviewing: (Bool) -> Void
    /// records (or clears) the slot a drag started from, so the drop delegate can tell an internal
    /// rearrange from an external file drop for both single-file and bundle drags.
    let setDraggingSource: (Int?) -> Void

    @State private var previewInfo: PreviewInfo?
    @State private var previewHovered = false
    @State private var buttonHovered = false
    @State private var loadTask: Task<Void, Never>?
    @State private var dismissTask: Task<Void, Never>?

    private var isBundle: Bool {
        item.files.count > 1
    }

    var body: some View {
        ZStack {
            content
                // a multi-file bundle drives clicks + drag through the AppKit drag source overlay, so the
                // visual content must not eat the events itself.
                .allowsHitTesting(!isBundle)
            if isBundle, !broken {
                SlotBundleDragSource(
                    urls: resolvedURLs,
                    sourceSlot: index,
                    onClick: onOpen,
                    setDraggingSource: setDraggingSource
                )
            }
        }
        .accessibilityLabel(broken ? "\(item.displayName), missing" : "Open \(item.displayName)")
        .contextMenu {
            // when at least one file resolves, keep the normal actions; offer Locate… whenever any file
            // is broken so a partially-broken bundle can repair its missing entry (spec §33, §38.1).
            if !broken {
                Button("Open") { onOpen() }
                Button("Reveal in Finder") { onReveal() }
                Button("Copy Path") { onCopyPath() }
                Button("Copy to Clipboard") { onCopy() }
                Button("Fill from Clipboard") { onFill() }
            }
            if hasBrokenFiles {
                Button("Locate…") { onLocate() }
            }
            Divider()
            Button("Remove from Shelf", role: .destructive) { onRemove() }
        }
        .overlay(alignment: .topLeading) {
            if isHovering, !broken {
                Button(action: onCopy) {
                    Image(systemName: "doc.on.clipboard.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .black.opacity(0.55))
                        .font(.body)
                }
                .buttonStyle(.plain)
                .padding(5)
                .accessibilityLabel("Copy \(item.displayName) to clipboard")
                // track button hover so the preview hides only while the cursor is over the button.
                .onHover { buttonHovered = $0 }
            }
        }
        .overlay(alignment: .topTrailing) {
            if isHovering {
                Button(action: onRemove) {
                    Image(systemName: "minus.circle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .black.opacity(0.55))
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .padding(5)
                .accessibilityLabel("Remove \(item.displayName) from shelf")
                // track button hover so the preview hides only while the cursor is over the button.
                .onHover { buttonHovered = $0 }
            }
        }
        .background(
            // a custom .applicationDefined NSPopover that does not steal the first outside mouse-down, so
            // a slot stays draggable while the preview is open (spec §20). hover-to-scroll still works.
            PreviewPopover(
                info: previewInfo,
                onOpen: { ShelfActions.openURL($0) },
                onCopy: onCopy
            ) { hovered in
                previewHovered = hovered
                if hovered { dismissTask?.cancel() } else { scheduleDismiss() }
            }
        )
        .onChange(of: isHovering) { _, hovering in
            // never show a preview while a drag is in progress or while the cursor is over a button.
            if hovering, !broken, !isDragging, !buttonHovered, primaryURL != nil {
                startPreviewLoad()
            } else {
                // reset button-hover so it can never get stuck true after the slot loses hover.
                buttonHovered = false
                loadTask?.cancel()
                scheduleDismiss()
            }
        }
        .onChange(of: buttonHovered) { _, over in
            // hide the preview while over a button (so its click registers first try), restore on return.
            if over {
                dismissPreview()
            } else if isHovering, !broken, primaryURL != nil {
                startPreviewLoad()
            }
        }
        .onChange(of: isDragging) { _, dragging in
            // any slot drag begins → dismiss the open preview at once so it can't cover lower slots.
            if dragging {
                dismissPreview()
            }
        }
    }

    /// immediately tears down the preview (cancels any pending load/dismiss and clears it).
    private func dismissPreview() {
        loadTask?.cancel()
        dismissTask?.cancel()
        previewInfo = nil
        setPreviewing(false)
    }

    /// the slot visual: stacked icons + count badge for a bundle, a plain icon for a single file. a
    /// single-file slot keeps the SwiftUI button + `.onDrag` path so it behaves exactly as before.
    @ViewBuilder private var content: some View {
        if isBundle {
            slotBody
        } else {
            Button(action: onOpen) { slotBody }
                .buttonStyle(.plain)
                .disabled(broken)
                // record the source slot in shared state (the private SlotDrag type does not survive the
                // swiftui drag->drop bridge), while still returning the real file url so drag-out works.
                .onDrag {
                    setDraggingSource(index)
                    Log.dragdrop.info("slot drag started from \(index)")
                    return dragProvider()
                }
        }
    }

    private var slotBody: some View {
        VStack(spacing: 4) {
            SlotIconStack(urls: resolvedURLs, fileCount: item.files.count)
            Text(item.displayName)
                .font(.caption2)
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            RoundedRectangle(cornerRadius: ShelfLayout.slotCornerRadius, style: .continuous)
                .fill(.white.opacity(isHovering ? 0.16 : 0))
        }
        .opacity(broken ? 0.5 : 1)
    }

    /// loads the preview after a short hover delay, then presents it (item-based popover, so it never
    /// flashes an empty popover before the content is ready) (spec §20).
    private func startPreviewLoad() {
        dismissTask?.cancel()
        loadTask?.cancel()
        loadTask = Task {
            try? await Task.sleep(for: .milliseconds(250))
            // bail if a drag began or the cursor reached a button during the load delay.
            guard !Task.isCancelled, !isDragging, !buttonHovered, let primaryURL else { return }
            let info: PreviewInfo
            if isBundle {
                // pair every still-resolving file with its url, in bundle order, for the file list.
                let entries = item.files.compactMap { file in
                    resolveFile(file).map { (file: file, url: $0) }
                }
                info = PreviewLoader.loadBundle(name: item.displayName, entries: entries)
            } else {
                let icon = IconProvider.icon(for: primaryURL, broken: false, size: 28)
                info = await PreviewLoader.load(
                    url: primaryURL,
                    kind: item.kind,
                    name: item.displayName,
                    icon: icon
                )
            }
            guard !Task.isCancelled else { return }
            previewInfo = info
            setPreviewing(true)
        }
    }

    /// dismiss after a short grace so the cursor can travel from the slot onto the (scrollable) preview.
    private func scheduleDismiss() {
        dismissTask?.cancel()
        dismissTask = Task {
            try? await Task.sleep(for: .milliseconds(220))
            guard !Task.isCancelled else { return }
            previewInfo = nil
            setPreviewing(false)
        }
    }

    /// single-file drag-out: the real file url (so Finder/other apps receive the actual file) plus a
    /// private payload tagging the source slot for internal rearranging; broken items do not drag.
    private func dragProvider() -> NSItemProvider {
        guard !broken, let url = primaryURL else { return NSItemProvider() }
        let provider = NSItemProvider(contentsOf: url) ?? NSItemProvider(object: url as NSURL)
        provider.registerDataRepresentation(forTypeIdentifier: SlotDrag.typeID, visibility: .ownProcess) { completion in
            completion(SlotDrag.data(for: index), nil)
            return nil
        }
        return provider
    }
}

// MARK: - SlotDropDelegate

/// distinguishes an internal rearrange (carries the private SlotDrag type → swap) from an external
/// file drop (→ a single bundle in this slot, falling forward when occupied) (spec §7, §11, §14, §16).
private struct SlotDropDelegate: DropDelegate {
    let index: Int
    let store: ShelfStore
    let uiState: ShelfUIState

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [.fileURL])
    }

    func dropEntered(info _: DropInfo) {
        uiState.isDragOver = true
        uiState.hoveredSlot = index
    }

    func dropExited(info _: DropInfo) {
        uiState.hoveredSlot = nil
        uiState.isDragOver = false
    }

    func performDrop(info: DropInfo) -> Bool {
        uiState.hoveredSlot = nil
        uiState.isDragOver = false
        // an internal slot-to-slot drag is identified by the live source slot in shared UI state, set for
        // BOTH single-file and bundle drags. the private SlotDrag type does not survive the swiftui (or the
        // AppKit) drag->drop bridge, so it is only a harmless secondary; draggingSourceSlot is authoritative.
        if let source = uiState.draggingSourceSlot {
            uiState.draggingSourceSlot = nil
            guard source != index else {
                // dropping a slot onto itself is a no-op.
                Log.dragdrop.info("internal drop ignored: source == drop slot \(index)")
                return true
            }
            Log.dragdrop.info("internal drop: swap \(source) -> \(index)")
            store.swap(source, index)
            return true
        }
        let providers = info.itemProviders(for: [.fileURL])
        Log.dragdrop.info("external drop onto slot \(index)")
        ShelfActions.dropBundle(providers, preferredSlot: index, store: store, uiState: uiState)
        return true
    }
}
