//
//  ShelfWindowController.swift
//  notchActions
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import AppKit
import SwiftUI

// MARK: - ShelfWindowController

/// owns the expanded shelf panel and the always-on transparent notch trigger (spec §8, §9, §37.2).
/// the trigger expands the shelf on hover or file-drag; while open, a lightweight cursor-position
/// monitor keeps it open as long as the cursor is over the shelf (or the notch) and collapses it once
/// the cursor has been away for a short delay. polling the live cursor position is robust during file
/// drags (where tracking-area enter/exit do not fire) and runs only while open, so idle CPU is unaffected.
@MainActor
final class ShelfWindowController {
    private let panel: ShelfPanel
    private let triggerWindow: NSPanel
    private let store: ShelfStore
    private let uiState: ShelfUIState

    private var screenObserver: NSObjectProtocol?
    private var hoverMonitorTask: Task<Void, Never>?
    private var hideTask: Task<Void, Never>?

    private static let collapseDelay: Duration = .milliseconds(350)
    private static let hideAfterCollapse: Duration = .milliseconds(420)
    private static let pollInterval: Duration = .milliseconds(120)
    private static let keepOpenMargin: CGFloat = 8

    // MARK: - Lifecycle

    init(store: ShelfStore, uiState: ShelfUIState) {
        self.store = store
        self.uiState = uiState

        panel = ShelfPanel(contentRect: Self.panelFrame() ?? CGRect(origin: .zero, size: NotchGeometry.panelSize))
        triggerWindow = NSPanel(
            contentRect: Self.triggerFrame() ?? .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        configurePanel()
        configureTrigger()
        observeScreenChanges()
        positionWindows()

        // start hidden: only the transparent trigger is live, so the app is invisible until the
        // cursor or a file-drag reaches the notch (spec §4.1 fully invisible collapsed state).
        triggerWindow.orderFrontRegardless()
    }

    // MARK: - Public control (in-shelf menu)

    func show() {
        expand()
    }

    func hide() {
        collapseNow()
    }

    // MARK: - Configuration

    private func configurePanel() {
        panel.contentView = NSHostingView(rootView: ShelfView(
            store: store,
            uiState: uiState
        ) { [weak self] in self?.hide() })
    }

    private func configureTrigger() {
        triggerWindow.isFloatingPanel = true
        triggerWindow.level = .statusBar
        triggerWindow.isOpaque = false
        triggerWindow.backgroundColor = .clear
        triggerWindow.hasShadow = false
        triggerWindow.ignoresMouseEvents = false
        // the app is essentially never frontmost, so keep the trigger ordered-in across deactivation
        // (NSPanel defaults this to true) — otherwise the only entry point dies once the app deactivates.
        triggerWindow.hidesOnDeactivate = false
        // float across normal Spaces but NOT over fullscreen apps (locked decision, spec §36.1).
        triggerWindow.collectionBehavior = [.canJoinAllSpaces, .stationary]

        let tracker = MouseTrackingView(acceptsDrag: true)
        tracker.onMouseEntered = { [weak self] in self?.expand() }
        tracker.onDragEntered = { [weak self] in self?.expand() }
        triggerWindow.contentView = tracker
    }

    // MARK: - Activation

    private func expand() {
        hideTask?.cancel()
        positionPanel()
        panel.orderFrontRegardless()
        uiState.isExpanded = true
        startHoverMonitor()
    }

    /// keep the shelf open while the live cursor is over the panel (or the notch); collapse once it
    /// has been away for the delay. works during file drags, and runs only while open (spec §8, §42).
    private func startHoverMonitor() {
        hoverMonitorTask?.cancel()
        hoverMonitorTask = Task { [weak self] in
            let clock = ContinuousClock()
            var awaySince: ContinuousClock.Instant?
            while !Task.isCancelled {
                guard let self else { return }
                if cursorIsOverShelf() {
                    awaySince = nil
                } else if let since = awaySince {
                    if clock.now - since >= Self.collapseDelay {
                        collapseNow()
                        return
                    }
                } else {
                    awaySince = clock.now
                }
                try? await Task.sleep(for: Self.pollInterval)
            }
        }
    }

    private func cursorIsOverShelf() -> Bool {
        let cursor = NSEvent.mouseLocation
        let panelArea = panel.frame.insetBy(dx: -Self.keepOpenMargin, dy: -Self.keepOpenMargin)
        return panelArea.contains(cursor) || triggerWindow.frame.contains(cursor)
    }

    private func collapseNow() {
        hoverMonitorTask?.cancel()
        hoverMonitorTask = nil
        uiState.isExpanded = false
        hideTask?.cancel()
        // order the (now invisible) panel out after the collapse animation so it stops covering
        // the screen region below the notch.
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: Self.hideAfterCollapse)
            guard let self, !uiState.isExpanded else { return }
            panel.orderOut(nil)
        }
    }

    // MARK: - Positioning

    func positionWindows() {
        positionPanel()
        if let triggerFrame = Self.triggerFrame() {
            triggerWindow.setFrame(triggerFrame, display: true)
        }
    }

    private func positionPanel() {
        guard let frame = Self.panelFrame() else { return }
        panel.setFrame(frame, display: true)
    }

    private static func metrics() -> NotchMetrics? {
        guard let screen = notchScreen() else { return nil }
        return NotchGeometry.metrics(for: screen)
    }

    /// always target the built-in notched display so the shelf stays at the notch no matter how many
    /// monitors are connected or which one is "main"; fall back to main if there is no physical notch.
    private static func notchScreen() -> NSScreen? {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main
    }

    private static func panelFrame() -> CGRect? {
        guard let metrics = metrics() else { return nil }
        return NotchGeometry.expandedPanelRect(metrics)
    }

    private static func triggerFrame() -> CGRect? {
        guard let metrics = metrics() else { return nil }
        return NotchGeometry.collapsedTriggerRect(metrics)
    }

    private func observeScreenChanges() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.positionWindows()
            }
        }
    }
}
