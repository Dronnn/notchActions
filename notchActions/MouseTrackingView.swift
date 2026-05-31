//
//  MouseTrackingView.swift
//  notchActions
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import AppKit

// MARK: - MouseTrackingView

/// transparent NSView that reports mouse enter/exit and file-drag entry via closures. used for the
/// always-on notch trigger and for the expanded panel's hover tracking (spec §8, §42 event-driven).
final class MouseTrackingView: NSView {
    var onMouseEntered: (() -> Void)?
    var onMouseExited: (() -> Void)?
    var onDragEntered: (() -> Void)?
    var onDragExited: (() -> Void)?

    init(acceptsDrag: Bool) {
        super.init(frame: .zero)
        if acceptsDrag {
            registerForDraggedTypes([.fileURL])
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas {
            removeTrackingArea(area)
        }
        addTrackingArea(NSTrackingArea(
            rect: .zero,
            options: [.activeAlways, .mouseEnteredAndExited, .inVisibleRect],
            owner: self
        ))
    }

    override func mouseEntered(with _: NSEvent) {
        onMouseEntered?()
    }

    override func mouseExited(with _: NSEvent) {
        onMouseExited?()
    }

    /// expand on drag approach; the actual drop is handled by the SwiftUI slots (spec §8.2, phase 7).
    override func draggingEntered(_: NSDraggingInfo) -> NSDragOperation {
        onDragEntered?()
        return []
    }

    /// a drag leaving or ending lets the controller reschedule the collapse it suppressed (spec §8.2).
    override func draggingExited(_: NSDraggingInfo?) {
        onDragExited?()
    }

    override func draggingEnded(_: NSDraggingInfo) {
        onDragExited?()
    }
}
