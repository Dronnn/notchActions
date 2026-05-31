//
//  LayoutConfigStore.swift
//  notchActions
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import Foundation
import Observation
import os

// MARK: - LayoutConfigStore

/// holds the configurable grid layout and persists it to UserDefaults; observing this object lets the
/// shelf re-lay-out live whenever the user changes rows or columns from the gear menu (spec §10.4, §22.5).
@MainActor
@Observable
final class LayoutConfigStore {
    private static let defaultsKey = "shelfLayoutConfig"
    private static let columnRange = 1 ... 8
    private static let rowRange = 1 ... 4

    /// sanitized on every mutation so callers always see a valid config.
    private(set) var config: ShelfLayoutConfig

    // MARK: - Lifecycle

    init() {
        config = Self.loadConfig()
    }

    // MARK: - Mutations

    /// adds or removes top-level rows; a new row defaults to the current last row's column count, clamped.
    func setRowCount(_ count: Int) {
        let target = min(max(count, Self.rowRange.lowerBound), Self.rowRange.upperBound)
        var rows = config.rowColumnCounts
        guard target != rows.count else { return }
        if target < rows.count {
            rows = Array(rows.prefix(target))
        } else {
            let fill = min(
                max(rows.last ?? Self.columnRange.lowerBound, Self.columnRange.lowerBound),
                Self.columnRange.upperBound
            )
            rows.append(contentsOf: Array(repeating: fill, count: target - rows.count))
        }
        update(rows)
    }

    /// sets a single row's column count, ignoring out-of-range row indices.
    func setColumns(forRow row: Int, to columns: Int) {
        guard config.rowColumnCounts.indices.contains(row) else { return }
        var rows = config.rowColumnCounts
        rows[row] = min(max(columns, Self.columnRange.lowerBound), Self.columnRange.upperBound)
        update(rows)
    }

    // MARK: - Helpers

    private func update(_ rows: [Int]) {
        let next = ShelfLayoutConfig(rowColumnCounts: rows).sanitized()
        guard next != config else { return }
        config = next
        persist()
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(config)
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        } catch {
            Log.persistence.error("layout config save failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func loadConfig() -> ShelfLayoutConfig {
        guard
            let data = UserDefaults.standard.data(forKey: defaultsKey),
            let decoded = try? JSONDecoder().decode(ShelfLayoutConfig.self, from: data)
        else {
            return .default
        }
        return decoded.sanitized()
    }
}
