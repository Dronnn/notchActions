//
//  ShelfItem.swift
//  notchActions
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import Foundation

// MARK: - ShelfItemKind

/// the kind of thing a shelf slot references (spec §38).
enum ShelfItemKind: String, Codable {
    case file
    case folder
    case application
    case markdownNote
}

// MARK: - ShelfItem

/// one shelf entry; references a user file via a security-scoped bookmark, never a copy (spec §24, §38).
struct ShelfItem: Identifiable, Codable, Equatable {
    let id: UUID
    var slotIndex: Int
    var kind: ShelfItemKind
    var displayName: String
    var bookmarkData: Data?
    var originalURLString: String?
    let createdAt: Date
    var updatedAt: Date
}
