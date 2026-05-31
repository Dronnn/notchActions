//
//  ShelfPanel.swift
//  notchActions
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import AppKit

// MARK: - ShelfPanel

/// borderless, non-activating floating panel that hosts the shelf UI (spec §7).
/// hovering or dragging must not steal app focus, yet the panel must still receive mouse, drag,
/// and click events. it is non-activating (never activates the app) and can become key on click.
final class ShelfPanel: NSPanel {
    init(contentRect: CGRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .statusBar
        isOpaque = false
        backgroundColor = .clear
        // force a dark appearance so the gear menu (and semantic colors) stay legible on the black panel.
        appearance = NSAppearance(named: .darkAqua)
        hasShadow = false // shadow is drawn by the SwiftUI content shape
        hidesOnDeactivate = false
        isMovableByWindowBackground = false
        isMovable = false
        // float across normal Spaces but NOT over fullscreen apps (locked decision, spec §36.1).
        collectionBehavior = [.canJoinAllSpaces, .stationary]
    }

    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        false
    }
}
