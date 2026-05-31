//
//  ShelfLayout.swift
//  notchActions
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import CoreGraphics

// MARK: - ShelfLayout

/// shared sizing for the U-shaped slot frame (2 left down, 4 across the bottom, 2 right down).
/// the panel size is derived from these constants so the window always matches the content.
enum ShelfLayout {
    static let slotSize: CGFloat = 72
    static let slotCornerRadius: CGFloat = 14
    static let iconSize: CGFloat = 36
    static let slotGap: CGFloat = 6
    static let rowGap: CGFloat = 8
    static let padding: CGFloat = 10

    // top inset that pushes the center gear/hint clear of the physical notch.
    static let notchClearance: CGFloat = 42
    static let panelCornerRadius: CGFloat = 24

    /// the expand animation grows the content out from roughly this notch-sized footprint at top-center.
    static let collapsedSize = CGSize(width: 180, height: 30)

    /// the bottom row is the widest band: left-column bottom + four bottom slots + right-column bottom.
    static let bottomRowCount = 4

    static var contentWidth: CGFloat {
        CGFloat(bottomRowCount) * slotSize + CGFloat(bottomRowCount - 1) * slotGap
    }

    static var panelSize: CGSize {
        CGSize(width: contentWidth + padding * 2, height: slotSize * 2 + rowGap + padding * 2)
    }
}
