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

    /// open/launch every file in the bundle with its default handler; never removes the item from the
    /// shelf (spec §12, §38). a single-file bundle behaves exactly like a classic open.
    static func open(_ item: ShelfItem, store: ShelfStore) {
        let urls = store.resolvedURLs(for: item)
        guard !urls.isEmpty else {
            Log.lifecycle.error("ignored open of broken item \(item.displayName, privacy: .public)")
            return
        }
        for url in urls {
            openURL(url)
        }
        Log.lifecycle.info("opened \(urls.count) file(s) from \(item.displayName, privacy: .public)")
    }

    /// opens one resolved url with its default handler inside the file's security scope (spec §12, §25).
    static func openURL(_ url: URL) {
        BookmarkResolver.withAccess(url) { resolved in
            NSWorkspace.shared.open(resolved)
        }
    }

    /// reveal the item's first resolving file in Finder (spec §30).
    static func reveal(_ item: ShelfItem, store: ShelfStore) {
        guard let url = store.firstResolvedURL(for: item) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    /// copy the item's first resolving file path to the pasteboard (spec §29).
    static func copyPath(_ item: ShelfItem, store: ShelfStore) {
        guard let url = store.firstResolvedURL(for: item) else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(url.path(percentEncoded: false), forType: .string)
    }

    /// copy the item's resolved file url reference(s) to the pasteboard, uniform for every kind so the
    /// receiver can paste real files; broken files are skipped (spec §29.1).
    static func copyToClipboard(_ item: ShelfItem, store: ShelfStore) {
        let urls = store.resolvedURLs(for: item)
        guard !urls.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects(urls.map { $0 as NSURL })
        Log.lifecycle.info("copied \(urls.count) file url(s) to clipboard")
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

    /// external multi-file drop onto ONE slot → a single bundle in that slot, in drag order; already
    /// shelved urls are skipped and a duplicate flashes the existing slot (spec §14, §38).
    static func dropBundle(
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
                Log.dragdrop.info("bundle drop produced no usable file urls")
                return
            }
            Log.dragdrop.info("bundle drop completed with \(urls.count) item(s)")
            switch store.addBundle(urls: urls, preferredSlot: preferredSlot) {
            case .added:
                break
            case let .duplicate(existingSlot):
                uiState.flash(slot: existingSlot)
            case .shelfFull:
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

    /// context-menu action: write the clipboard into a new markdown note and add it to THIS slot —
    /// appended to an occupied slot's bundle, or filling an empty slot (spec §29.2).
    static func fillFromClipboard(slot: Int, store: ShelfStore, uiState: ShelfUIState) {
        switch ClipboardMarkdownService.writeClipboardNote() {
        case let .success(url):
            store.appendNote(url: url, isAppCreated: true, to: slot)
        case .failure:
            // empty/unsupported clipboard is a quiet no-op, consistent with §18.
            Log.clipboard.info("fill from clipboard produced no note")
        }
    }

    /// gear-menu action: drop the shelf's references to app-created notes first, then delete those note
    /// files on disk. pruning before deletion keeps classification on the stored path (no stranded refs),
    /// and the symlink-guarded enumeration never follows a link out of the notes dir. user files are never
    /// touched; the notes directory itself is kept (spec §23.1).
    static func clearCache(store: ShelfStore) {
        store.clearCache()
        deleteNoteFilesOnDisk()
        Log.lifecycle.info("cleared cache")
    }

    /// deletes only the app-owned clipboard notes on disk: direct children of the notes dir that are
    /// regular .md files (never directories, never symlinks, never recursed). bails entirely if the notes
    /// dir is not a real directory or if any ancestor up to the support root is a symlink, so a relinked
    /// ancestor can never redirect the deletion outside the app's own storage.
    private static func deleteNoteFilesOnDisk() {
        let fileManager = FileManager.default
        let notesDir = AppPaths.clipboardNotesDir
        guard isRealDirectory(notesDir), ancestorChainIsUnlinked(notesDir) else {
            Log.persistence
                .error(
                    "clear cache: notes dir unsafe (missing, not a dir, or symlinked ancestor); skipped"
                )
            return
        }
        guard
            let contents = try? fileManager.contentsOfDirectory(
                at: notesDir,
                includingPropertiesForKeys: [.isSymbolicLinkKey, .isRegularFileKey]
            )
        else { return }
        for url in contents where isDeletableNote(url) {
            do {
                try fileManager.removeItem(at: url)
            } catch {
                Log.persistence.error(
                    "clear cache: failed to delete \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)"
                )
            }
        }
    }

    /// a deletable note: a direct child that is a regular file, is not a symlink, and ends in .md.
    private static func isDeletableNote(_ url: URL) -> Bool {
        guard url.pathExtension.lowercased() == "md" else { return false }
        guard
            let values = try? url.resourceValues(forKeys: [.isSymbolicLinkKey, .isRegularFileKey])
        else { return false }
        return values.isRegularFile == true && values.isSymbolicLink != true
    }

    /// true when every path component from the notes dir up to and including the support root is a real
    /// (non-symlink) entry; uses no-follow resourceValues so it never resolves a link before checking it.
    private static func ancestorChainIsUnlinked(_ notesDir: URL) -> Bool {
        let root = AppPaths.supportDir.standardizedFileURL
        var current = notesDir.standardizedFileURL
        while true {
            let isLink = (try? current.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) ?? false
            if isLink { return false }
            if current.path(percentEncoded: false) == root.path(percentEncoded: false) { return true }
            let parent = current.deletingLastPathComponent().standardizedFileURL
            // stop if we have climbed above the root without matching it, or cannot ascend further.
            guard
                parent != current,
                parent.path(percentEncoded: false).count >= root.path(percentEncoded: false).count
            else {
                return false
            }
            current = parent
        }
    }

    /// a url that resolves to a real directory that is not itself a symbolic link.
    private static func isRealDirectory(_ url: URL) -> Bool {
        guard
            let values = try? url.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey])
        else { return false }
        return values.isDirectory == true && values.isSymbolicLink != true
    }
}
