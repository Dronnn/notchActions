//
//  LayoutSettingsView.swift
//  notchActions
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import SwiftUI

// MARK: - LayoutSettingsView

/// the floating Layout settings window content: a rows stepper plus one column stepper per row, a live
/// preview of the resulting grid, and a Done button. it edits the same shared `LayoutConfigStore` the
/// shelf observes, so changes persist and the shelf re-lays-out on its next summon (spec §10.4, §22.5).
struct LayoutSettingsView: View {
    let layoutConfig: LayoutConfigStore
    let onDone: () -> Void

    private static let width: CGFloat = 320
    private static let rowRange = 1 ... 4
    private static let columnRange = 1 ... 8

    private var rowCount: Binding<Int> {
        Binding(
            get: { layoutConfig.config.rowColumnCounts.count },
            set: { layoutConfig.setRowCount($0) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Layout")
                .font(.headline)

            StepperField(title: "Rows", value: rowCount, range: Self.rowRange)

            ForEach(layoutConfig.config.rowColumnCounts.indices, id: \.self) { row in
                StepperField(title: "Row \(row + 1)", value: columnsBinding(forRow: row), range: Self.columnRange)
            }

            LayoutPreviewView(layoutConfig: layoutConfig)
                .frame(maxWidth: .infinity)

            HStack {
                Spacer()
                Button("Done", action: onDone)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: Self.width)
    }

    // MARK: - Helpers

    /// a stale binding can outlive a row-count reduction, so guard the read against the live count.
    private func columnsBinding(forRow row: Int) -> Binding<Int> {
        Binding(
            get: {
                let counts = layoutConfig.config.rowColumnCounts
                return counts.indices.contains(row) ? counts[row] : 1
            },
            set: { layoutConfig.setColumns(forRow: row, to: $0) }
        )
    }
}
