//
//  LayoutPreviewTopRow.swift
//  notchActions
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import SwiftUI

// MARK: - LayoutPreviewTopRow

struct LayoutPreviewTopRow: View {
    let row: ShelfGrid.Row
    let skippedCount: Int

    var body: some View {
        HStack(spacing: LayoutPreviewView.gap) {
            ForEach(row.left, id: \.slotIndex) { _ in LayoutPreviewSlot() }
            let gapWidth = LayoutPreviewView.gapWidth(skippedCount: skippedCount)
            if gapWidth > 0 {
                Color.clear.frame(width: gapWidth)
            }
            ForEach(row.right, id: \.slotIndex) { _ in LayoutPreviewSlot() }
        }
    }
}
