//
//  SlotView.swift
//  notchActions
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import AppKit
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
                    onOpen: { ShelfActions.open(item, store: store) },
                    onRemove: { store.remove(slot: index) },
                    onReveal: { ShelfActions.reveal(item, store: store) },
                    onCopyPath: { ShelfActions.copyPath(item, store: store) },
                    onCopy: { ShelfActions.copyToClipboard(item, store: store) },
                    onFill: { ShelfActions.fillFromClipboard(slot: index, store: store, uiState: uiState) },
                    onLocate: { ShelfActions.locate(item, store: store) },
                    resolveFile: { store.resolvedURL(for: $0) },
                    setPreviewing: { uiState.isPreviewing = $0 }
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
    let onOpen: () -> Void
    let onRemove: () -> Void
    let onReveal: () -> Void
    let onCopyPath: () -> Void
    let onCopy: () -> Void
    let onFill: () -> Void
    let onLocate: () -> Void
    let resolveFile: (ShelfFile) -> URL?
    let setPreviewing: (Bool) -> Void

    @State private var previewInfo: PreviewInfo?
    @State private var previewHovered = false
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
                SlotBundleDragSource(urls: resolvedURLs, sourceSlot: index, onClick: onOpen)
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
            }
        }
        .popover(item: $previewInfo, arrowEdge: .bottom) { info in
            ShelfPreviewView(info: info, onOpen: { ShelfActions.openURL($0) }, onCopy: onCopy)
                .onHover { hovered in
                    previewHovered = hovered
                    if hovered { dismissTask?.cancel() } else { scheduleDismiss() }
                }
        }
        .onChange(of: isHovering) { _, hovering in
            if hovering, !broken, primaryURL != nil {
                startPreviewLoad()
            } else {
                loadTask?.cancel()
                scheduleDismiss()
            }
        }
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
                .onDrag { dragProvider() }
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
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled, let primaryURL else { return }
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
        let providers = info.itemProviders(for: [.fileURL])
        if let internalProvider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(SlotDrag.typeID) }) {
            internalProvider.loadDataRepresentation(forTypeIdentifier: SlotDrag.typeID) { data, _ in
                guard let data, let source = SlotDrag.index(from: data) else { return }
                Task { @MainActor in store.swap(source, index) }
            }
            return true
        }
        ShelfActions.dropBundle(providers, preferredSlot: index, store: store, uiState: uiState)
        return true
    }
}
