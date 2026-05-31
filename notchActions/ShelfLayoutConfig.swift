//
//  ShelfLayoutConfig.swift
//  notchActions
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import Foundation

// MARK: - ShelfLayoutConfig

/// the configurable grid: an ordered list of per-row column counts, e.g. [7, 6] is a top row of seven
/// plus a row of six (spec §10.4, §22.5). the top row sits at the notch and auto-skips its center
/// columns, so a default of seven renders as two-plus-two around the notch (spec §10.5).
struct ShelfLayoutConfig: Codable, Equatable {
    var rowColumnCounts: [Int]

    static let `default` = ShelfLayoutConfig(rowColumnCounts: [7, 6])

    private static let rowRange = 1 ... 4
    private static let columnRange = 1 ... 8

    /// clamps each row to 1...8 columns and the row count to 1...4 rows; falls back to the default when
    /// the config is empty or otherwise invalid (spec §22.5).
    func sanitized() -> ShelfLayoutConfig {
        let clampedColumns = rowColumnCounts.map { $0.clamped(to: Self.columnRange) }
        guard !clampedColumns.isEmpty else { return .default }
        let rows = Array(clampedColumns.prefix(Self.rowRange.upperBound))
        return ShelfLayoutConfig(rowColumnCounts: rows)
    }
}

// MARK: - Comparable clamping

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
