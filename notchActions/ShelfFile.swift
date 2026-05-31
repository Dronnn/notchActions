//
//  ShelfFile.swift
//  notchActions
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import Foundation

// MARK: - ShelfItemKind

/// the kind of thing a shelf file references (spec §38).
enum ShelfItemKind: String, Codable {
    case file
    case folder
    case application
    case markdownNote
}

// MARK: - ShelfFile

/// one file inside a shelf bundle; references a user file via a security-scoped bookmark, never a copy
/// (spec §24, §38). `isAppCreated` is true for clipboard-derived notes the app itself wrote (spec §38.3).
struct ShelfFile: Identifiable, Codable, Equatable {
    let id: UUID
    var kind: ShelfItemKind
    var displayName: String
    var bookmarkData: Data?
    var originalURLString: String?
    var isAppCreated: Bool
}
