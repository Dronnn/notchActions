//
//  LayoutPreviewSlot.swift
//  notchActions
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import SwiftUI

// MARK: - LayoutPreviewSlot

struct LayoutPreviewSlot: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(.white.opacity(0.22))
            .frame(width: LayoutPreviewView.slot, height: LayoutPreviewView.slot)
    }
}
