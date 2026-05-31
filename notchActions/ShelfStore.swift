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
/// stores only references/bookmarks to user files; never copies, moves, or deletes them (spec §24).
@MainActor
@Observable
final class ShelfStore {
    // MARK: - AddResult

    enum AddResult: Equatable {
        case added(slot: Int)
        case duplicate(existingSlot: Int)
        case shelfFull
    }

    // MARK: - Constants

    static let slotCount = 8

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
        (0 ..< Self.slotCount).first { item(at: $0) == nil }
    }

    var emptySlots: [Int] {
        (0 ..< Self.slotCount).filter { item(at: $0) == nil }
    }

    /// resolves an item to a live file url, preferring its security-scoped bookmark and falling
    /// back to the stored original path; nil means the item is broken (spec §25, §33).
    /// intentionally pure (no mutation) so it is safe to call during a SwiftUI view update.
    func resolvedURL(for item: ShelfItem) -> URL? {
        if
            let data = item.bookmarkData,
            let resolved = BookmarkResolver.resolve(data),
            FileManager.default.fileExists(atPath: resolved.url.path(percentEncoded: false))
        {
            return resolved.url
        }
        if
            let string = item.originalURLString,
            let url = URL(string: string),
            FileManager.default.fileExists(atPath: url.path(percentEncoded: false))
        {
            return url
        }
        return nil
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
        let item = makeItem(for: url, kind: kind, slot: slot)
        items.append(item)
        Log.persistence.info("added \(item.displayName, privacy: .public) at slot \(slot)")
        save()
        return .added(slot: slot)
    }

    /// adds the first url at `slot` (if free) and the rest into the following empty slots,
    /// wrapping around, so a plus-click on slot 5 fills 5, 6, 7, ... (spec §11).
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

    /// drops the reference/bookmark only; never touches the file on disk (spec §17, §24).
    func remove(slot: Int) {
        guard let index = items.firstIndex(where: { $0.slotIndex == slot }) else { return }
        let removed = items.remove(at: index)
        Log.persistence.info("removed \(removed.displayName, privacy: .public) from slot \(slot)")
        save()
    }

    /// swaps the contents of two slots; a swap with an empty target is just a move (spec §16).
    /// guards against out-of-range slots so bad drag data can never persist an invalid index.
    func swap(_ slotA: Int, _ slotB: Int) {
        let range = 0 ..< Self.slotCount
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

    /// re-link a (broken) item to a moved file: recreate its bookmark and refresh name/kind (spec §33).
    func relink(slot: Int, to url: URL) {
        guard let index = items.firstIndex(where: { $0.slotIndex == slot }) else { return }
        items[index].bookmarkData = try? BookmarkResolver.makeBookmark(for: url)
        items[index].originalURLString = url.absoluteString
        let name = (try? url.resourceValues(forKeys: [.localizedNameKey]).localizedName) ?? url.lastPathComponent
        items[index].displayName = name
        items[index].kind = BookmarkResolver.classify(url)
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

    /// tolerates a missing or corrupt store by starting empty (spec §44).
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

    /// refreshes bookmarks that still resolve but report stale, so references survive chains of
    /// file moves; runs once at launch where it can safely mutate state (spec §25 resilience).
    private func healStaleBookmarks() {
        var didChange = false
        for index in items.indices {
            guard
                let data = items[index].bookmarkData,
                let resolved = BookmarkResolver.resolve(data),
                resolved.isStale,
                FileManager.default.fileExists(atPath: resolved.url.path(percentEncoded: false)),
                let fresh = try? BookmarkResolver.makeBookmark(for: resolved.url) else { continue }
            let name = items[index].displayName
            items[index].bookmarkData = fresh
            items[index].originalURLString = resolved.url.absoluteString
            items[index].updatedAt = .now
            didChange = true
            Log.persistence.info("refreshed stale bookmark for \(name, privacy: .public)")
        }
        if didChange {
            save()
        }
    }

    // MARK: - Helpers

    /// matches on the stored original path and, for moved files, on the resolved bookmark path,
    /// so re-adding a file that has moved still flashes the existing slot instead of duplicating.
    private func existingItem(for url: URL) -> ShelfItem? {
        let target = url.standardizedFileURL.path(percentEncoded: false)
        return items.first { item in
            if
                let string = item.originalURLString,
                let existing = URL(string: string),
                existing.standardizedFileURL.path(percentEncoded: false) == target
            {
                return true
            }
            if
                let resolved = resolvedURL(for: item),
                resolved.standardizedFileURL.path(percentEncoded: false) == target
            {
                return true
            }
            return false
        }
    }

    private func chooseSlot(preferred: Int?) -> Int? {
        if let preferred, (0 ..< Self.slotCount).contains(preferred), item(at: preferred) == nil {
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

    private func makeItem(for url: URL, kind: ShelfItemKind, slot: Int) -> ShelfItem {
        let bookmark = try? BookmarkResolver.makeBookmark(for: url)
        if bookmark == nil {
            // not fatal: in a non-sandboxed app the originalURLString fallback still resolves (spec §13, §25).
            Log.persistence.error("bookmark creation failed for \(url.path(percentEncoded: false), privacy: .public)")
        }
        let name = (try? url.resourceValues(forKeys: [.localizedNameKey]).localizedName) ?? url.lastPathComponent
        return ShelfItem(
            id: UUID(),
            slotIndex: slot,
            kind: kind,
            displayName: name,
            bookmarkData: bookmark,
            originalURLString: url.absoluteString,
            createdAt: .now,
            updatedAt: .now
        )
    }

    private func sanitized(_ loaded: [ShelfItem]) -> [ShelfItem] {
        var seen = Set<Int>()
        var result: [ShelfItem] = []
        for item in loaded.sorted(by: { $0.slotIndex < $1.slotIndex }) {
            guard (0 ..< Self.slotCount).contains(item.slotIndex), !seen.contains(item.slotIndex) else {
                continue
            }
            seen.insert(item.slotIndex)
            result.append(item)
        }
        return result
    }
}
