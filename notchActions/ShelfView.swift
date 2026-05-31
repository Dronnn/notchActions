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
    let onHide: () -> Void

    var body: some View {
        ShelfPanelContent(store: store, uiState: uiState, onHide: onHide)
            // grow out from a notch-sized footprint at top-center to the full shelf, so it reads
            // like it unrolls from the notch (spec §9).
            .frame(
                width: uiState.isExpanded ? ShelfLayout.panelSize.width : ShelfLayout.collapsedSize.width,
                height: uiState.isExpanded ? ShelfLayout.panelSize.height : ShelfLayout.collapsedSize.height,
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
    let onHide: () -> Void

    /// U fill order (locked: 2 left down, 4 bottom across, 2 right down). the top row carries the
    /// corner slots 0 and 6 with the notch-facing center open; the bottom row carries 1,2,3,4,5,7.
    private let bottomRow = [1, 2, 3, 4, 5, 7]

    private var shelfShape: UnevenRoundedRectangle {
        .rect(
            topLeadingRadius: 0,
            bottomLeadingRadius: ShelfLayout.panelCornerRadius,
            bottomTrailingRadius: ShelfLayout.panelCornerRadius,
            topTrailingRadius: 0
        )
    }

    var body: some View {
        VStack(spacing: ShelfLayout.rowGap) {
            HStack(spacing: ShelfLayout.slotGap) {
                SlotView(index: 0, store: store, uiState: uiState)
                Spacer(minLength: ShelfLayout.slotGap)
                ShelfCenterControls(store: store, uiState: uiState, onHide: onHide)
                Spacer(minLength: ShelfLayout.slotGap)
                SlotView(index: 6, store: store, uiState: uiState)
            }
            HStack(spacing: ShelfLayout.slotGap) {
                ForEach(bottomRow, id: \.self) { index in
                    SlotView(index: index, store: store, uiState: uiState)
                }
            }
        }
        .padding(ShelfLayout.padding)
        .frame(width: ShelfLayout.panelSize.width, height: ShelfLayout.panelSize.height)
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
        .overlay(alignment: .bottom) {
            if uiState.fullShelfToast {
                FullShelfToast()
            }
        }
        .animation(.easeInOut(duration: 0.2), value: uiState.isDragOver)
    }
}

// MARK: - ShelfCenterControls

/// the open center under the notch: a small menu (the app's only control surface, since there is
/// no menu-bar item) plus the first-launch hint. opacity keeps the layout stable when items change.
private struct ShelfCenterControls: View {
    let store: ShelfStore
    let uiState: ShelfUIState
    let onHide: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            Menu {
                Button("Paste Clipboard as Markdown") { ShelfActions.pasteClipboard(store: store, uiState: uiState) }
                Button("Clear Shelf") { store.clear() }
                Button("Hide Shelf") { onHide() }
                Divider()
                Toggle("Open at Login", isOn: Binding(get: { LoginItem.isEnabled }, set: { LoginItem.setEnabled($0) }))
                Divider()
                Button("Quit notchActions") { ShelfActions.quit() }
            } label: {
                Image(systemName: "gearshape")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.85))
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
