//
//  SlotDrag.swift
//  notchActions
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import Foundation

// MARK: - SlotDrag

/// a private, in-process drag payload that tags a shelf drag with its source slot, so a drop can
/// tell an internal rearrange (swap) from an external file drop (spec §11, §40). it travels
/// alongside the real file url, which is what Finder and other apps receive on drag-out.
enum SlotDrag {
    static let typeID = "com.notchactions.slot"

    nonisolated static func data(for index: Int) -> Data {
        Data("\(index)".utf8)
    }

    nonisolated static func index(from data: Data) -> Int? {
        guard let string = String(data: data, encoding: .utf8) else { return nil }
        return Int(string)
    }
}
