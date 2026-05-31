//
//  ShelfGrid.swift
//  notchActions
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import CoreGraphics

// MARK: - ShelfGrid

/// pure layout math for the configurable grid: from a `ShelfLayoutConfig`, the physical notch width,
/// and the `ShelfLayout` constants it derives the auto-skipped center gap, the rendered slot layout
/// with sequential slot indices, the total slot count, and the panel size (spec §10.4, §10.5).
struct ShelfGrid {
    // MARK: - Cell

    /// one rendered slot: its assigned sequential index and the top-row local column it sits in.
    /// `column` lets the top row align its left/right groups with the gap; unused for lower rows.
    struct Cell: Equatable {
        let slotIndex: Int
        let column: Int
    }

    /// one rendered row. the top row may carry a centered notch gap, so its cells are split into a left
    /// group and a right group; lower rows put everything in `left` with an empty `right`.
    struct Row: Equatable {
        let left: [Cell]
        let right: [Cell]
        let isTop: Bool

        var all: [Cell] {
            left + right
        }

        /// the row's first sequential slot index; unique per row (row-major assignment), so it makes a
        /// stable identity for rendering rows in a ForEach.
        var startSlotIndex: Int {
            all.first?.slotIndex ?? -1
        }
    }

    let config: ShelfLayoutConfig
    let rows: [Row]
    let totalSlotCount: Int
    let skippedCount: Int
    let panelSize: CGSize

    /// extra height reserved above the grid for the center gear + hint when the top-row notch gap is too
    /// narrow to hold them; 0 when the gap is wide enough (the tuned notched-Mac layout) (spec §10.5.2).
    let controlsBandHeight: CGFloat

    // MARK: - Derived

    /// width of the centered spacer between the top row's left and right groups: exactly the block of
    /// skipped center columns (their cells plus internal gaps). the surrounding HStack adds one slotGap
    /// on each side, restoring the gaps that flank the block, so both groups stay column-aligned with
    /// the full rows below (spec §10.5.1, §10.5.2).
    var topRowGapWidth: CGFloat {
        Self.topRowGapWidth(skippedCount: skippedCount)
    }

    // MARK: - Init

    /// notchWidth is 0 on a Mac without a physical notch, so nothing is skipped there (spec §10.5.1).
    init(config: ShelfLayoutConfig, notchWidth: CGFloat) {
        let config = config.sanitized()
        let counts = config.rowColumnCounts
        let skipped = Self.skippedCount(topColumns: counts.first ?? 0, notchWidth: notchWidth)
        let built = Self.makeRows(counts: counts, skippedCount: skipped)
        // the gap holds the controls only when it is wide enough; otherwise a dedicated band is reserved.
        let band = Self.topRowGapWidth(skippedCount: skipped) >= ShelfLayout.controlsMinGapWidth
            ? 0
            : ShelfLayout.controlsBandHeight

        self.config = config
        skippedCount = skipped
        rows = built.rows
        totalSlotCount = built.totalSlotCount
        controlsBandHeight = band
        panelSize = Self.panelSize(counts: counts, controlsBandHeight: band)
    }

    // MARK: - Math

    /// width of the centered spacer between the top row's left and right groups for a given skip count.
    private static func topRowGapWidth(skippedCount: Int) -> CGFloat {
        guard skippedCount > 0 else { return 0 }
        return CGFloat(skippedCount) * ShelfLayout.slotSize + CGFloat(skippedCount - 1) * ShelfLayout.slotGap
    }

    /// number of top-row center columns hidden under the notch, kept centered (spec §10.5.1). the gap is
    /// only centered when the skipped count shares the top row's parity, so when the raw skip and
    /// topColumns differ in parity we bump the skip by one before capping. the cap max(0, topColumns - 2)
    /// preserves topColumns parity, so the gap stays centered after clamping.
    private static func skippedCount(topColumns: Int, notchWidth: CGFloat) -> Int {
        guard notchWidth > 0 else { return 0 }
        let cellPitch = ShelfLayout.slotSize + ShelfLayout.slotGap
        guard cellPitch > 0 else { return 0 }
        var rawSkip = Int(ceil(notchWidth / cellPitch))
        if rawSkip % 2 != topColumns % 2 {
            rawSkip += 1
        }
        let maxSkip = max(0, topColumns - 2)
        return min(rawSkip, maxSkip)
    }

    /// rendered rows with sequential slot indices (row-major, top→bottom, left→right); the top row's
    /// centered hidden columns are skipped and split it into a left and a right group (spec §10.5.1).
    private static func makeRows(counts: [Int], skippedCount: Int) -> (rows: [Row], totalSlotCount: Int) {
        let topColumns = counts.first ?? 0
        let firstHidden = (topColumns - skippedCount) / 2
        let hiddenRange = firstHidden ..< (firstHidden + skippedCount)

        var nextSlot = 0
        var rows: [Row] = []
        for (rowIndex, columns) in counts.enumerated() {
            guard rowIndex == 0 else {
                let cells = (0 ..< columns).map { column -> Cell in
                    defer { nextSlot += 1 }
                    return Cell(slotIndex: nextSlot, column: column)
                }
                rows.append(Row(left: cells, right: [], isTop: false))
                continue
            }
            var left: [Cell] = []
            var right: [Cell] = []
            for column in 0 ..< columns where !hiddenRange.contains(column) {
                let cell = Cell(slotIndex: nextSlot, column: column)
                nextSlot += 1
                if column < firstHidden { left.append(cell) } else { right.append(cell) }
            }
            rows.append(Row(left: left, right: right, isTop: true))
        }
        return (rows, nextSlot)
    }

    /// the widest row drives the width; rows plus row gaps drive the height, plus the controls band when
    /// the notch gap is too narrow to hold the gear + hint (spec §10.5.2).
    private static func panelSize(counts: [Int], controlsBandHeight: CGFloat) -> CGSize {
        let maxColumns = counts.max() ?? 0
        let rowCount = counts.count
        let contentWidth = CGFloat(maxColumns) * ShelfLayout.slotSize
            + CGFloat(max(0, maxColumns - 1)) * ShelfLayout.slotGap
        let contentHeight = CGFloat(rowCount) * ShelfLayout.slotSize
            + CGFloat(max(0, rowCount - 1)) * ShelfLayout.rowGap
        return CGSize(
            width: contentWidth + ShelfLayout.padding * 2,
            height: contentHeight + ShelfLayout.padding * 2 + ShelfLayout.notchClearance + controlsBandHeight
        )
    }
}
