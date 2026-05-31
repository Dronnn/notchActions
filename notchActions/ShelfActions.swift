//
//  ShelfActions.swift
//  notchActions
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import AppKit
import os

// MARK: - ShelfActions

/// imperative user actions that touch AppKit, kept out of the SwiftUI views (spec §11, §12).
@MainActor
enum ShelfActions {
    /// plus button → native open panel; first item to preferredSlot, rest fill forward (spec §11).
    static func addViaOpenPanel(preferredSlot: Int?, store: ShelfStore, uiState: ShelfUIState) {
        // the panel is non-activating, so bring the app forward before showing a modal picker
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.resolvesAliases = true
        guard panel.runModal() == .OK else { return }
        let result = store.addMany(urls: panel.urls, startingAt: preferredSlot)
        if let duplicateSlot = result.firstDuplicateSlot {
            uiState.flash(slot: duplicateSlot)
        }
        if result.overflow > 0 {
            uiState.showFull()
        }
    }

    /// open/launch an item with its default handler; never remove it from the shelf (spec §12).
    static func open(_ item: ShelfItem, store: ShelfStore) {
        guard let url = store.resolvedURL(for: item) else {
            Log.lifecycle.error("ignored open of broken item \(item.displayName, privacy: .public)")
            return
        }
        BookmarkResolver.withAccess(url) { resolved in
            NSWorkspace.shared.open(resolved)
        }
        Log.lifecycle.info("opened \(item.displayName, privacy: .public)")
    }

    /// reveal the item in Finder (spec §30).
    static func reveal(_ item: ShelfItem, store: ShelfStore) {
        guard let url = store.resolvedURL(for: item) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    /// copy the item's file path to the pasteboard (spec §29).
    static func copyPath(_ item: ShelfItem, store: ShelfStore) {
        guard let url = store.resolvedURL(for: item) else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(url.path(percentEncoded: false), forType: .string)
    }

    /// re-link a broken item to a moved file via an open panel (spec §33).
    static func locate(_ item: ShelfItem, store: ShelfStore) {
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.resolvesAliases = true
        guard panel.runModal() == .OK, let url = panel.urls.first else { return }
        store.relink(slot: item.slotIndex, to: url)
    }

    /// external file drop → add to the shelf, filling forward from the target slot (spec §7, §14).
    static func dropFiles(
        _ providers: [NSItemProvider],
        preferredSlot: Int?,
        store: ShelfStore,
        uiState: ShelfUIState
    ) {
        Task {
            var urls: [URL] = []
            for provider in providers {
                if let url = await loadURL(provider) {
                    urls.append(url)
                }
            }
            guard !urls.isEmpty else {
                Log.dragdrop.info("drop produced no usable file urls")
                return
            }
            Log.dragdrop.info("drop completed with \(urls.count) item(s)")
            let result = store.addMany(urls: urls, startingAt: preferredSlot)
            if let duplicateSlot = result.firstDuplicateSlot {
                uiState.flash(slot: duplicateSlot)
            }
            if result.overflow > 0 {
                uiState.showFull()
            }
        }
    }

    private static func loadURL(_ provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                continuation.resume(returning: url)
            }
        }
    }

    /// terminate the app; the only quit path now that there is no menu-bar item (spec §21).
    static func quit() {
        Log.lifecycle.info("quit requested")
        NSApp.terminate(nil)
    }

    /// menu action: turn the current clipboard text into a markdown note on the shelf (spec §18).
    static func pasteClipboard(store: ShelfStore, uiState: ShelfUIState) {
        switch ClipboardMarkdownService.makeNote(addingTo: store) {
        case .success:
            break
        case .failure(.noSlot):
            uiState.showFull()
        case .failure:
            Log.clipboard.info("paste produced no note")
        }
    }
}
