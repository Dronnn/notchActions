//
//  ShelfView.swift
//  notchActions
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import SwiftUI

// MARK: - ShelfView

/// root content hosted in the panel; animates between the invisible collapsed state and the
/// expanded shelf, growing downward from the notch with no window resize (spec §6, §9, §27).
struct ShelfView: View {
    let store: ShelfStore
    let uiState: ShelfUIState
    let layoutConfig: LayoutConfigStore
    let notchWidth: CGFloat
    let onHide: () -> Void

    /// rebuilt whenever the observed layout config changes so the shelf re-lays-out live (spec §10.4).
    private var grid: ShelfGrid {
        ShelfGrid(config: layoutConfig.config, notchWidth: notchWidth)
    }

    var body: some View {
        ShelfPanelContent(store: store, uiState: uiState, grid: grid, layoutConfig: layoutConfig, onHide: onHide)
            // grow out from a notch-sized footprint at top-center to the full shelf, so it reads
            // like it unrolls from the notch (spec §9).
            .frame(
                width: uiState.isExpanded ? grid.panelSize.width : ShelfLayout.collapsedSize.width,
                height: uiState.isExpanded ? grid.panelSize.height : ShelfLayout.collapsedSize.height,
                alignment: .top
            )
            .clipped()
            .opacity(uiState.isExpanded ? 1 : 0)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .animation(.spring(response: 0.34, dampingFraction: 0.82), value: uiState.isExpanded)
    }
}

// MARK: - ShelfPanelContent

private struct ShelfPanelContent: View {
    let store: ShelfStore
    let uiState: ShelfUIState
    let grid: ShelfGrid
    let layoutConfig: LayoutConfigStore
    let onHide: () -> Void

    private var shelfShape: UnevenRoundedRectangle {
        .rect(
            topLeadingRadius: 0,
            bottomLeadingRadius: ShelfLayout.panelCornerRadius,
            bottomTrailingRadius: ShelfLayout.panelCornerRadius,
            topTrailingRadius: 0
        )
    }

    var body: some View {
        ShelfGridRows(grid: grid, store: store, uiState: uiState)
            // reserve the notch clearance entirely at the top so the top row sits flush under the
            // notch and the gear (overlaid below the same clearance) fills the center gap (spec §10.5.2).
            .padding(.top, ShelfLayout.notchClearance)
            .padding(ShelfLayout.padding)
            .frame(width: grid.panelSize.width, height: grid.panelSize.height, alignment: .top)
            .background {
                // plain black so the panel reads as part of the notch (spec §27).
                shelfShape.fill(.black)
            }
            .overlay {
                shelfShape
                    .strokeBorder(
                        uiState.isDragOver ? Color.accentColor.opacity(0.85) : .white.opacity(0.18),
                        lineWidth: uiState.isDragOver ? 2 : 1
                    )
            }
            .clipShape(shelfShape)
            .shadow(color: .black.opacity(0.35), radius: 14, y: 6)
            .overlay(alignment: .top) {
                // gear + hint live in the open center, pushed below the notch so they aren't clipped.
                ShelfCenterControls(store: store, uiState: uiState, layoutConfig: layoutConfig, onHide: onHide)
                    .padding(.top, ShelfLayout.notchClearance)
            }
            .overlay(alignment: .bottom) {
                if uiState.fullShelfToast {
                    FullShelfToast()
                }
            }
            .animation(.easeInOut(duration: 0.2), value: uiState.isDragOver)
    }
}

// MARK: - ShelfGridRows

/// renders the active grid: the top row splits into a left and a right group around a centered notch
/// gap, every lower row is a full-width row, stacked with the locked row gap (spec §10.4, §10.5).
private struct ShelfGridRows: View {
    let grid: ShelfGrid
    let store: ShelfStore
    let uiState: ShelfUIState

    var body: some View {
        VStack(spacing: ShelfLayout.rowGap) {
            ForEach(grid.rows, id: \.startSlotIndex) { row in
                if row.isTop {
                    ShelfTopRow(row: row, gapWidth: grid.topRowGapWidth, store: store, uiState: uiState)
                } else {
                    ShelfLowerRow(row: row, store: store, uiState: uiState)
                }
            }
        }
    }
}

// MARK: - ShelfTopRow

/// the notch-facing row: a left group and a right group separated by a centered gap exactly as wide as
/// the auto-skipped center columns, so both groups stay column-aligned with the rows below (spec §10.5).
private struct ShelfTopRow: View {
    let row: ShelfGrid.Row
    let gapWidth: CGFloat
    let store: ShelfStore
    let uiState: ShelfUIState

    var body: some View {
        HStack(spacing: ShelfLayout.slotGap) {
            ForEach(row.left, id: \.slotIndex) { cell in
                SlotView(index: cell.slotIndex, store: store, uiState: uiState)
            }
            if gapWidth > 0 {
                Color.clear.frame(width: gapWidth)
            }
            ForEach(row.right, id: \.slotIndex) { cell in
                SlotView(index: cell.slotIndex, store: store, uiState: uiState)
            }
        }
    }
}

// MARK: - ShelfLowerRow

/// a full-width row below the notch: every configured column rendered left to right, no center gap.
private struct ShelfLowerRow: View {
    let row: ShelfGrid.Row
    let store: ShelfStore
    let uiState: ShelfUIState

    var body: some View {
        HStack(spacing: ShelfLayout.slotGap) {
            ForEach(row.all, id: \.slotIndex) { cell in
                SlotView(index: cell.slotIndex, store: store, uiState: uiState)
            }
        }
    }
}

// MARK: - ShelfCenterControls

/// the open center under the notch: a small menu (the app's only control surface, since there is
/// no menu-bar item) plus the first-launch hint. opacity keeps the layout stable when items change.
private struct ShelfCenterControls: View {
    let store: ShelfStore
    let uiState: ShelfUIState
    let layoutConfig: LayoutConfigStore
    let onHide: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            Menu {
                Button("Paste Clipboard as Markdown") { ShelfActions.pasteClipboard(store: store, uiState: uiState) }
                Button("Clear Shelf") { store.clear() }
                Button("Clear Cache") { ShelfActions.clearCache(store: store) }
                Button("Hide Shelf") { onHide() }
                Divider()
                Menu("Layout") {
                    LayoutMenuItems(layoutConfig: layoutConfig)
                }
                Divider()
                Toggle("Open at Login", isOn: Binding(get: { LoginItem.isEnabled }, set: { LoginItem.setEnabled($0) }))
                Divider()
                Button("Quit notchActions") { ShelfActions.quit() }
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .padding(6)
                    .background(Circle().fill(.white.opacity(0.16)))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel("notchActions menu")

            Text("Drag files here or press +")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
                .fixedSize()
                .opacity(store.items.isEmpty ? 1 : 0)
        }
    }
}

// MARK: - LayoutMenuItems

/// the gear-menu "Layout" submenu: a row-count stepper plus one column stepper per row, bound to the
/// observed LayoutConfigStore so each change re-lays-out the shelf live (spec §22.5, §10.4).
private struct LayoutMenuItems: View {
    let layoutConfig: LayoutConfigStore

    private var rowCount: Binding<Int> {
        Binding(
            get: { layoutConfig.config.rowColumnCounts.count },
            set: { layoutConfig.setRowCount($0) }
        )
    }

    var body: some View {
        Stepper("Rows", value: rowCount, in: 1 ... 4)
        // iterate the collection's own indices (always valid) instead of enumerated(), which is not a
        // RandomAccessCollection on swift 5.9 and so cannot back a ForEach.
        ForEach(layoutConfig.config.rowColumnCounts.indices, id: \.self) { row in
            Stepper("Row \(row + 1) columns", value: columnsBinding(forRow: row), in: 1 ... 8)
        }
    }

    private func columnsBinding(forRow row: Int) -> Binding<Int> {
        Binding(
            // a stale binding can outlive a row-count reduction, so guard the read against the live count.
            get: {
                let counts = layoutConfig.config.rowColumnCounts
                return counts.indices.contains(row) ? counts[row] : 1
            },
            set: { layoutConfig.setColumns(forRow: row, to: $0) }
        )
    }
}

// MARK: - FullShelfToast

private struct FullShelfToast: View {
    var body: some View {
        Text("Shelf is full")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.thinMaterial, in: .capsule)
            .padding(.bottom, 8)
    }
}
