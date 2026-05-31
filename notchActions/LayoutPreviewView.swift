//
//  LayoutPreviewView.swift
//  notchActions
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import AppKit
import SwiftUI

// MARK: - LayoutPreviewView

/// a small, non-interactive live preview of the shelf grid shape; it builds a `ShelfGrid` from the
/// shared layout config and the notch width of the built-in notched display (0 when none), then draws
/// each row as little rounded rectangles, mirroring how `ShelfView` arranges rows (top row split into a
/// left and a right group around the centered notch gap, lower rows full). updates live as config changes.
struct LayoutPreviewView: View {
    let layoutConfig: LayoutConfigStore

    private static let slotSize: CGFloat = 16
    private static let slotGap: CGFloat = 3
    private static let rowGap: CGFloat = 4

    private var grid: ShelfGrid {
        ShelfGrid(config: layoutConfig.config, notchWidth: Self.notchWidth)
    }

    var body: some View {
        VStack(spacing: Self.rowGap) {
            ForEach(grid.rows, id: \.startSlotIndex) { row in
                if row.isTop {
                    LayoutPreviewTopRow(row: row, skippedCount: grid.skippedCount)
                } else {
                    LayoutPreviewFullRow(cells: row.all)
                }
            }
        }
        .padding(8)
        .background(.black, in: .rect(cornerRadius: 8))
    }

    // MARK: - Geometry

    /// notch width of the built-in notched display so the preview gap matches the real shelf; 0 (no gap)
    /// when no physical notch is present.
    private static var notchWidth: CGFloat {
        guard let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) else { return 0 }
        return NotchGeometry.notchWidth(for: screen)
    }

    /// width of the centered gap between the top row's two groups, scaled to the preview slot size.
    static func gapWidth(skippedCount: Int) -> CGFloat {
        guard skippedCount > 0 else { return 0 }
        return CGFloat(skippedCount) * slotSize + CGFloat(skippedCount - 1) * slotGap
    }

    static var slot: CGFloat {
        slotSize
    }

    static var gap: CGFloat {
        slotGap
    }
}
