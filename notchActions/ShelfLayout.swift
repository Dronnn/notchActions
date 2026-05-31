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

    /// the expand animation grows the content out from roughly this notch-sized footprint at top-center.
    static let collapsedSize = CGSize(width: 180, height: 30)
}
