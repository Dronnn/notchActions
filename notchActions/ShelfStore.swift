//
//  ShelfStore.swift
//  notchActions
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import Foundation
import Observation
import os

// MARK: - ShelfStore

/// in-memory shelf state with JSON persistence and slot operations (spec §13, §31, §32).
/// each slot holds a bundle of one or more files; stores only references/bookmarks, never copies,
/// moves, or deletes the user's files (spec §24, §38).
@MainActor
@Observable
final class ShelfStore {
    // MARK: - AddResult

    enum AddResult: Equatable {
        case added(slot: Int)
        case duplicate(existingSlot: Int)
        case shelfFull
    }

    // MARK: - BundleAddResult

    /// like AddResult, but `.added` also reports the first already-shelved file's slot (if the same drop
    /// mixed new and duplicate files), so the caller can flash that existing slot (spec §14, §31).
    enum BundleAddResult: Equatable {
        case added(slot: Int, firstDuplicateSlot: Int?)
        case duplicate(existingSlot: Int)
        case shelfFull
    }

    // MARK: - Slot count

    /// number of rendered slots. settable so group B can wire the grid-derived count; the window
    /// controller overwrites this from the active grid at launch. it intentionally does not gate load()
    /// (see sanitized()), so the placeholder value can never truncate persisted items.
    var slotCount = 10

    // MARK: - State

    /// sparse list; each item has a unique slotIndex in 0..<slotCount.
    private(set) var items: [ShelfItem] = []

    // MARK: - Lifecycle

    init() {
        load()
        healStaleBookmarks()
    }

    // MARK: - Queries

    func item(at slot: Int) -> ShelfItem? {
        items.first { $0.slotIndex == slot }
    }

    var firstEmptySlot: Int? {
        (0 ..< slotCount).first { item(at: $0) == nil }
    }

    var emptySlots: [Int] {
        (0 ..< slotCount).filter { item(at: $0) == nil }
    }

    /// resolves a single file to a live url, preferring its security-scoped bookmark and falling back
    /// to the stored original path; nil means that file is broken (spec §25, §33). pure (no mutation),
    /// so it is safe to call during a SwiftUI view update.
    func resolvedURL(for file: ShelfFile) -> URL? {
        if
            let data = file.bookmarkData,
            let resolved = BookmarkResolver.resolve(data),
            FileManager.default.fileExists(atPath: resolved.url.path(percentEncoded: false))
        {
            return resolved.url
        }
        if
            let string = file.originalURLString,
            let url = URL(string: string),
            FileManager.default.fileExists(atPath: url.path(percentEncoded: false))
        {
            return url
        }
        return nil
    }

    /// resolves the item's primary file; nil when the whole bundle is broken (spec §33).
    func resolvedURL(for item: ShelfItem) -> URL? {
        guard let primary = item.primaryFile else { return nil }
        return resolvedURL(for: primary)
    }

    /// every resolving url in the bundle, in bundle order; broken files are skipped (spec §12, §29.1).
    func resolvedURLs(for item: ShelfItem) -> [URL] {
        item.files.compactMap { resolvedURL(for: $0) }
    }

    /// the first resolving url of the bundle, in bundle order; nil only when the whole bundle is broken.
    /// single-target actions (reveal, copy path) use this so they never act on a broken primary file
    /// while a later file in the bundle still resolves (spec §29, §30, §33).
    func firstResolvedURL(for item: ShelfItem) -> URL? {
        resolvedURLs(for: item).first
    }

    func contains(url: URL) -> Bool {
        existingItem(for: url) != nil
    }

    // MARK: - Mutations

    /// duplicates are rejected and the existing slot reported back for a flash (spec §31).
    func add(url: URL, kind: ShelfItemKind, preferredSlot: Int?) -> AddResult {
        if let existing = existingItem(for: url) {
            Log.persistence.info("rejected duplicate \(url.lastPathComponent, privacy: .public)")
            return .duplicate(existingSlot: existing.slotIndex)
        }
        guard let slot = chooseSlot(preferred: preferredSlot) else {
            return .shelfFull
        }
        let item = makeItem(for: [url], slot: slot)
        items.append(item)
        Log.persistence.info("added \(item.displayName, privacy: .public) at slot \(slot)")
        save()
        return .added(slot: slot)
    }

    /// adds the first url at `slot` (if free) and the rest into the following empty slots, wrapping
    /// around, so a plus-click on slot 5 fills 5, 6, 7, ... — one file per slot (spec §11).
    @discardableResult
    func addMany(urls: [URL], startingAt slot: Int?) -> (addedCount: Int, overflow: Int, firstDuplicateSlot: Int?) {
        var addedCount = 0
        var overflow = 0
        var firstDuplicateSlot: Int?
        for url in urls {
            switch add(
                url: url,
                kind: BookmarkResolver.classify(url),
                preferredSlot: nextForwardEmptySlot(from: slot)
            ) {
            case .added:
                addedCount += 1
            case let .duplicate(existingSlot):
                if firstDuplicateSlot == nil {
                    firstDuplicateSlot = existingSlot
                }
            case .shelfFull:
                overflow += 1
            }
        }
        return (addedCount, overflow, firstDuplicateSlot)
    }

    /// drops several files onto ONE slot as a single bundle, in drag order; the same file dropped twice in
    /// one drop is added once, and already-shelved urls are skipped so the bundle never duplicates an
    /// existing item. when the preferred slot is taken the bundle falls forward to the next empty slot
    /// (spec §14, §38).
    @discardableResult
    func addBundle(urls: [URL], preferredSlot: Int?) -> BundleAddResult {
        let deduped = deduplicatedByPath(urls)
        let fresh = deduped.filter { existingItem(for: $0) == nil }
        let firstDuplicateSlot = deduped.lazy.compactMap { self.existingItem(for: $0)?.slotIndex }.first
        guard !fresh.isEmpty else {
            if let firstDuplicateSlot {
                return .duplicate(existingSlot: firstDuplicateSlot)
            }
            return .shelfFull
        }
        guard let slot = chooseSlot(preferred: nextForwardEmptySlot(from: preferredSlot)) else {
            return .shelfFull
        }
        let item = makeItem(for: fresh, slot: slot)
        items.append(item)
        Log.persistence.info("added bundle of \(item.files.count) at slot \(slot)")
        save()
        return .added(slot: slot, firstDuplicateSlot: firstDuplicateSlot)
    }

    /// drops repeated urls in one drop, keyed by standardized path, preserving first-seen order.
    private func deduplicatedByPath(_ urls: [URL]) -> [URL] {
        var seen = Set<String>()
        return urls.filter { seen.insert($0.standardizedFileURL.path(percentEncoded: false)).inserted }
    }

    /// appends a note file to a slot's bundle (occupied slot) or fills an empty slot with it (spec §29.2).
    /// `isAppCreated` marks clipboard-derived notes so Clear Cache can find them (spec §23.1, §38.3).
    func appendNote(url: URL, isAppCreated: Bool, to slot: Int) {
        let file = makeFile(for: url, isAppCreated: isAppCreated)
        if let index = items.firstIndex(where: { $0.slotIndex == slot }) {
            items[index].files.append(file)
            items[index].updatedAt = .now
            Log.persistence.info("appended note to slot \(slot)")
        } else {
            let item = ShelfItem(id: UUID(), slotIndex: slot, files: [file], createdAt: .now, updatedAt: .now)
            items.append(item)
            Log.persistence.info("created note bundle at slot \(slot)")
        }
        save()
    }

    /// drops the references/bookmarks only; never touches files on disk (spec §17, §24).
    func remove(slot: Int) {
        guard let index = items.firstIndex(where: { $0.slotIndex == slot }) else { return }
        let removed = items.remove(at: index)
        Log.persistence.info("removed \(removed.displayName, privacy: .public) from slot \(slot)")
        save()
    }

    /// swaps the contents of two slots; a swap with an empty target is just a move (spec §16).
    /// guards against out-of-range slots so bad drag data can never persist an invalid index.
    func swap(_ slotA: Int, _ slotB: Int) {
        let range = 0 ..< slotCount
        guard slotA != slotB, range.contains(slotA), range.contains(slotB) else { return }
        let indexA = items.firstIndex { $0.slotIndex == slotA }
        let indexB = items.firstIndex { $0.slotIndex == slotB }
        guard indexA != nil || indexB != nil else { return }
        if let indexA {
            items[indexA].slotIndex = slotB
            items[indexA].updatedAt = .now
        }
        if let indexB {
            items[indexB].slotIndex = slotA
            items[indexB].updatedAt = .now
        }
        Log.persistence.info("swapped slots \(slotA) and \(slotB)")
        save()
    }

    /// removes all references; keeps every file on disk, generated notes included (spec §23).
    func clear() {
        guard !items.isEmpty else { return }
        items.removeAll()
        Log.persistence.info("cleared shelf")
        save()
    }

    /// drops app-created files from every bundle and removes any slot left empty; the files themselves are
    /// deleted on disk afterwards by ShelfActions.clearCache (spec §23.1). a file counts as app-created
    /// when `isAppCreated` is set or its STORED path is a true descendant of the notes dir — classified
    /// from the stored path alone so it still matches after the disk file is gone (no stranded refs).
    func clearCache() {
        let notesComponents = AppPaths.clipboardNotesDir.standardizedFileURL.pathComponents
        var didChange = false
        for index in items.indices {
            let kept = items[index].files.filter { !isAppCreated($0, notesComponents: notesComponents) }
            if kept.count != items[index].files.count {
                items[index].files = kept
                items[index].updatedAt = .now
                didChange = true
            }
        }
        let before = items.count
        items.removeAll { $0.files.isEmpty }
        if items.count != before { didChange = true }
        if didChange {
            Log.persistence.info("cleared cache references")
            save()
        }
    }

    /// true when the file is one of ours: explicitly marked, or its stored original path is a STRICT
    /// descendant of the notes dir (component-prefix, so a sibling like "Clipboard Notes Backup/x.md" is
    /// never matched). uses the stored path, never disk existence, so it holds after the file is deleted.
    private func isAppCreated(_ file: ShelfFile, notesComponents: [String]) -> Bool {
        if file.isAppCreated { return true }
        guard
            let string = file.originalURLString,
            let url = URL(string: string)
        else { return false }
        let components = url.standardizedFileURL.pathComponents
        guard components.count > notesComponents.count else { return false }
        return Array(components.prefix(notesComponents.count)) == notesComponents
    }

    /// on an EXPLICIT user-driven capacity reduction, pulls items that fell out of range (slotIndex >=
    /// newSlotCount) back into the earliest empty in-range slot, in ascending old-slot order; items with
    /// no in-range slot left stay where they are (preserved-but-hidden, never deleted). position-only, so
    /// it does not bump updatedAt. saves once. only the layout-config path calls this — never the
    /// screen/notch path (spec §10.4, §22.5).
    func repack(into newSlotCount: Int) {
        guard newSlotCount >= 0 else { return }
        let overflowing = items.indices
            .filter { items[$0].slotIndex >= newSlotCount }
            .sorted { items[$0].slotIndex < items[$1].slotIndex }
        guard !overflowing.isEmpty else { return }
        var occupied = Set(items.map(\.slotIndex))
        var didChange = false
        for index in overflowing {
            guard let target = (0 ..< newSlotCount).first(where: { !occupied.contains($0) }) else { continue }
            occupied.remove(items[index].slotIndex)
            items[index].slotIndex = target
            occupied.insert(target)
            didChange = true
        }
        if didChange {
            Log.persistence.info("repacked shelf into \(newSlotCount) slot(s)")
            save()
        }
    }

    /// re-link a slot's first broken file to a moved file, leaving the bundle's still-resolving and any
    /// other broken files intact (spec §33). a single-file bundle is replaced outright; a multi-file bundle
    /// whose files all resolve is left untouched so relinking can never collapse or lose bundle files.
    func relink(slot: Int, to url: URL) {
        guard let index = items.firstIndex(where: { $0.slotIndex == slot }) else { return }
        let relinked = makeFile(for: url, isAppCreated: false)
        if let brokenIndex = items[index].files.firstIndex(where: { resolvedURL(for: $0) == nil }) {
            items[index].files[brokenIndex] = relinked
        } else if items[index].files.count == 1 {
            items[index].files = [relinked]
        } else {
            return
        }
        items[index].updatedAt = .now
        Log.persistence.info("relinked slot \(slot)")
        save()
    }

    // MARK: - Persistence

    /// atomic pretty-printed json; never crashes on failure (spec §35, §44).
    func save() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(items)
            try data.write(to: AppPaths.storeFile, options: [.atomic])
        } catch {
            Log.persistence.error("save failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// tolerates a missing or corrupt store by starting empty; also migrates the legacy flat shape
    /// into single-file bundles via ShelfItem's custom decoding (spec §38.2, §44).
    private func load() {
        let url = AppPaths.storeFile
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else {
            items = []
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let loaded = try sanitized(decoder.decode([ShelfItem].self, from: data))
            items = loaded
            Log.persistence.info("loaded \(loaded.count) shelf item(s)")
        } catch {
            Log.persistence.error("load failed, starting empty: \(error.localizedDescription, privacy: .public)")
            items = []
        }
    }

    /// refreshes bookmarks that still resolve but report stale, so references survive chains of file
    /// moves; runs once at launch where it can safely mutate state (spec §25 resilience).
    private func healStaleBookmarks() {
        var didChange = false
        for itemIndex in items.indices {
            for fileIndex in items[itemIndex].files.indices {
                guard
                    let data = items[itemIndex].files[fileIndex].bookmarkData,
                    let resolved = BookmarkResolver.resolve(data),
                    resolved.isStale,
                    FileManager.default.fileExists(atPath: resolved.url.path(percentEncoded: false)),
                    let fresh = try? BookmarkResolver.makeBookmark(for: resolved.url) else { continue }
                let name = items[itemIndex].files[fileIndex].displayName
                items[itemIndex].files[fileIndex].bookmarkData = fresh
                items[itemIndex].files[fileIndex].originalURLString = resolved.url.absoluteString
                items[itemIndex].updatedAt = .now
                didChange = true
                Log.persistence.info("refreshed stale bookmark for \(name, privacy: .public)")
            }
        }
        if didChange {
            save()
        }
    }

    // MARK: - Helpers

    /// matches on any file's stored original path and, for moved files, on the resolved bookmark path,
    /// so re-adding a file that has moved still flashes the existing slot instead of duplicating.
    private func existingItem(for url: URL) -> ShelfItem? {
        let target = url.standardizedFileURL.path(percentEncoded: false)
        return items.first { item in
            item.files.contains { file in
                if
                    let string = file.originalURLString,
                    let existing = URL(string: string),
                    existing.standardizedFileURL.path(percentEncoded: false) == target
                {
                    return true
                }
                if
                    let resolved = resolvedURL(for: file),
                    resolved.standardizedFileURL.path(percentEncoded: false) == target
                {
                    return true
                }
                return false
            }
        }
    }

    private func chooseSlot(preferred: Int?) -> Int? {
        if let preferred, (0 ..< slotCount).contains(preferred), item(at: preferred) == nil {
            return preferred
        }
        return firstEmptySlot
    }

    /// the next empty slot at or after `start`, wrapping to the earliest empty slot; used to fill
    /// multi-selections forward from the slot the user acted on.
    private func nextForwardEmptySlot(from start: Int?) -> Int? {
        let empties = emptySlots
        guard let start else { return empties.first }
        return empties.first { $0 >= start } ?? empties.first
    }

    private func makeItem(for urls: [URL], slot: Int) -> ShelfItem {
        let files = urls.map { makeFile(for: $0, isAppCreated: false) }
        return ShelfItem(id: UUID(), slotIndex: slot, files: files, createdAt: .now, updatedAt: .now)
    }

    private func makeFile(for url: URL, isAppCreated: Bool) -> ShelfFile {
        let bookmark = try? BookmarkResolver.makeBookmark(for: url)
        if bookmark == nil {
            // not fatal: in a non-sandboxed app the originalURLString fallback still resolves (spec §13, §25).
            Log.persistence.error("bookmark creation failed for \(url.path(percentEncoded: false), privacy: .public)")
        }
        let name = (try? url.resourceValues(forKeys: [.localizedNameKey]).localizedName) ?? url.lastPathComponent
        let kind: ShelfItemKind = isAppCreated ? .markdownNote : BookmarkResolver.classify(url)
        return ShelfFile(
            id: UUID(),
            kind: kind,
            displayName: name,
            bookmarkData: bookmark,
            originalURLString: url.absoluteString,
            isAppCreated: isAppCreated
        )
    }

    /// keeps non-negative, unique-slot, non-empty bundles only; does NOT clamp slotIndex to the current
    /// slotCount. load() runs during init before the grid-derived slotCount is wired, so an upper clamp
    /// here would drop items in higher slots (data loss). out-of-range-high items are simply not rendered
    /// by ShelfGrid and reappear when the grid grows again (spec §10.4). a negative slotIndex can only
    /// come from a malformed store, so those items are dropped.
    private func sanitized(_ loaded: [ShelfItem]) -> [ShelfItem] {
        var seen = Set<Int>()
        var result: [ShelfItem] = []
        for item in loaded.sorted(by: { $0.slotIndex < $1.slotIndex }) {
            guard item.slotIndex >= 0, !seen.contains(item.slotIndex), !item.files.isEmpty else {
                continue
            }
            seen.insert(item.slotIndex)
            result.append(item)
        }
        return result
    }
}
