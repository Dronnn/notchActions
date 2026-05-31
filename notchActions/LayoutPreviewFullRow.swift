//
//  LayoutPreviewFullRow.swift
//  notchActions
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import SwiftUI

// MARK: - LayoutPreviewFullRow

struct LayoutPreviewFullRow: View {
    let cells: [ShelfGrid.Cell]

    var body: some View {
        HStack(spacing: LayoutPreviewView.gap) {
            ForEach(cells, id: \.slotIndex) { _ in LayoutPreviewSlot() }
        }
    }
}
