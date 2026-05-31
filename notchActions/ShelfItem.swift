//
//  ShelfItem.swift
//  notchActions
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import Foundation

// MARK: - ShelfItem

/// one shelf slot occupant: a bundle of one or more files. a single-file bundle looks exactly like a
/// classic occupied slot (spec §38). stores only references/bookmarks to user files; never copies them.
struct ShelfItem: Identifiable, Codable, Equatable {
    let id: UUID
    var slotIndex: Int
    var files: [ShelfFile]
    let createdAt: Date
    var updatedAt: Date

    // MARK: - Derived

    /// the file that drives the slot's icon and primary name (spec §38.1).
    var primaryFile: ShelfFile? {
        files.first
    }

    /// label shown under the slot: the single file's name, or "N items" for a multi-file bundle (spec §38.1).
    var displayName: String {
        files.count > 1 ? "\(files.count) items" : (primaryFile?.displayName ?? "")
    }

    /// kind of the primary file; kept so single-file slots behave exactly as before (spec §38.1).
    var kind: ShelfItemKind {
        primaryFile?.kind ?? .file
    }

    /// a slot is broken only when none of its files resolve; one resolving file keeps it usable (spec §38.1).
    func isBroken(using resolve: (ShelfFile) -> URL?) -> Bool {
        !files.contains { resolve($0) != nil }
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case id, slotIndex, files, createdAt, updatedAt
    }

    /// legacy flat keys (single-file shape) used by stores written before multi-file bundles (spec §38.2).
    private enum LegacyKeys: String, CodingKey {
        case kind, displayName, bookmarkData, originalURLString
    }

    init(id: UUID, slotIndex: Int, files: [ShelfFile], createdAt: Date, updatedAt: Date) {
        self.id = id
        self.slotIndex = slotIndex
        self.files = files
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// decodes the new bundle shape, or migrates the legacy flat single-file record into a one-file
    /// bundle when `files` is absent (spec §38.2).
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        slotIndex = try container.decode(Int.self, forKey: .slotIndex)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)

        if let files = try container.decodeIfPresent([ShelfFile].self, forKey: .files) {
            self.files = files
            return
        }

        // legacy flat shape → one-file bundle
        let legacy = try decoder.container(keyedBy: LegacyKeys.self)
        let kind = try legacy.decode(ShelfItemKind.self, forKey: .kind)
        let file = try ShelfFile(
            id: UUID(),
            kind: kind,
            displayName: legacy.decode(String.self, forKey: .displayName),
            bookmarkData: legacy.decodeIfPresent(Data.self, forKey: .bookmarkData),
            originalURLString: legacy.decodeIfPresent(String.self, forKey: .originalURLString),
            isAppCreated: kind == .markdownNote
        )
        files = [file]
    }

    /// always writes the new bundle shape (spec §38.2). explicit because the custom init(from:) drops
    /// the synthesized Encodable conformance.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(slotIndex, forKey: .slotIndex)
        try container.encode(files, forKey: .files)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}
