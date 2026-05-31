//
//  ShelfUIState.swift
//  notchActions
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import Observation

// MARK: - ShelfUIState

/// transient UI state for the shelf: expansion, drag-over, hover, the duplicate flash, and the
/// "shelf is full" toast. kept separate from the persistent ShelfStore.
@MainActor
@Observable
final class ShelfUIState {
    var isExpanded = false
    var isDragOver = false
    var hoveredSlot: Int?
    var highlightSlot: Int?
    var fullShelfToast = false
    var isPreviewing = false

    private static let transientDuration: Duration = .milliseconds(1_200)

    private var highlightTask: Task<Void, Never>?
    private var toastTask: Task<Void, Never>?

    /// briefly rings an existing slot when a duplicate add is rejected (spec §31).
    func flash(slot: Int) {
        highlightSlot = slot
        highlightTask?.cancel()
        highlightTask = Task { [weak self] in
            try? await Task.sleep(for: Self.transientDuration)
            guard !Task.isCancelled else { return }
            self?.highlightSlot = nil
        }
    }

    /// shows the transient "shelf is full" toast (spec §32).
    func showFull() {
        fullShelfToast = true
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: Self.transientDuration)
            guard !Task.isCancelled else { return }
            self?.fullShelfToast = false
        }
    }
}
