//
//  ShelfLayout.swift
//  notchActions
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import CoreGraphics

// MARK: - ShelfLayout

/// shared per-slot sizing for the configurable grid (spec §10.4, §10.5). the panel size itself is no
/// longer derived here — it comes from `ShelfGrid` given the active layout config.
enum ShelfLayout {
    static let slotSize: CGFloat = 72
    static let slotCornerRadius: CGFloat = 14
    static let iconSize: CGFloat = 36
    static let slotGap: CGFloat = 6
    static let rowGap: CGFloat = 10
    static let padding: CGFloat = 10

    // top inset that pushes the center gear/hint clear of the physical notch.
    static let notchClearance: CGFloat = 42
    static let panelCornerRadius: CGFloat = 24

    /// the center gear + hint need at least this much horizontal room. when the top-row notch gap is this
    /// wide the controls sit inside the gap (the tuned notched-Mac layout); when it is narrower they get
    /// their own band so they never overlap a slot (spec §10.5.2).
    static let controlsMinGapWidth: CGFloat = 180

    /// height of the dedicated controls band reserved above the grid when the notch gap is too narrow to
    /// hold the gear + hint; added to the panel height so nothing overlaps.
    static let controlsBandHeight: CGFloat = 44

    /// the expand animation grows the content out from roughly this notch-sized footprint at top-center.
    static let collapsedSize = CGSize(width: 180, height: 30)
}
