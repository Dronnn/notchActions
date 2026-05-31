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
/// duplicate-flash ring, and the drag-over highlight (spec §10, §14, §16, §41, §43).
struct SlotView: View {
    let index: Int
    let store: ShelfStore
    let uiState: ShelfUIState

    @State private var isHovering = false

    var body: some View {
        let item = store.item(at: index)
        let url = item.flatMap { store.resolvedURL(for: $0) }
        let broken = item != nil && url == nil

        Group {
            if let item {
                OccupiedSlotView(
                    index: index,
                    item: item,
                    url: url,
                    broken: broken,
                    isHovering: isHovering,
                    onOpen: { ShelfActions.open(item, store: store) },
                    onRemove: { store.remove(slot: index) },
                    onReveal: { ShelfActions.reveal(item, store: store) },
                    onCopyPath: { ShelfActions.copyPath(item, store: store) }
                )
            } else {
                EmptySlotView(isHovering: isHovering) {
                    ShelfActions.addViaOpenPanel(preferredSlot: index, store: store, uiState: uiState)
                }
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
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: ShelfLayout.slotCornerRadius, style: .continuous)
                .fill(.white.opacity(isHovering ? 0.10 : 0.05))
                .overlay {
                    RoundedRectangle(cornerRadius: ShelfLayout.slotCornerRadius, style: .continuous)
                        .strokeBorder(.white.opacity(isHovering ? 0.35 : 0.18), lineWidth: 1)
                }
                .overlay {
                    Image(systemName: "plus")
                        .font(.title)
                        .foregroundStyle(.secondary)
                        .scaleEffect(isHovering ? 1.12 : 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add item")
    }
}

// MARK: - OccupiedSlotView

private struct OccupiedSlotView: View {
    let index: Int
    let item: ShelfItem
    let url: URL?
    let broken: Bool
    let isHovering: Bool
    let onOpen: () -> Void
    let onRemove: () -> Void
    let onReveal: () -> Void
    let onCopyPath: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(spacing: 4) {
                Image(nsImage: IconProvider.icon(for: url, broken: broken, size: ShelfLayout.iconSize))
                    .resizable()
                    .frame(width: ShelfLayout.iconSize, height: ShelfLayout.iconSize)
                Text(item.displayName)
                    .font(.caption2)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                RoundedRectangle(cornerRadius: ShelfLayout.slotCornerRadius, style: .continuous)
                    .fill(.white.opacity(isHovering ? 0.10 : 0))
            }
            .opacity(broken ? 0.5 : 1)
        }
        .buttonStyle(.plain)
        .disabled(broken)
        .accessibilityLabel(broken ? "\(item.displayName), missing" : "Open \(item.displayName)")
        .onDrag { dragProvider() }
        .contextMenu {
            if !broken {
                Button("Open") { onOpen() }
                Button("Reveal in Finder") { onReveal() }
                Button("Copy Path") { onCopyPath() }
                Divider()
            }
            Button("Remove from Shelf", role: .destructive) { onRemove() }
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
    }

    /// drag-out provides the real file url (so Finder/other apps receive the actual file) plus a
    /// private payload tagging the source slot for internal rearranging; broken items do not drag.
    private func dragProvider() -> NSItemProvider {
        guard !broken, let url else { return NSItemProvider() }
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
/// file drop (→ add), and drives the drag-over highlight (spec §7, §11, §16).
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
        ShelfActions.dropFiles(providers, preferredSlot: index, store: store, uiState: uiState)
        return true
    }
}
