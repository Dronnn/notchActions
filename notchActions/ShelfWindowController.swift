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

/// owns the expanded shelf panel and the always-on transparent notch trigger, and drives the
/// hover/drag activation and the debounced collapse (spec §8, §9, §37.2).
///
/// the panel is always physically expanded-size, so it never resizes mid-animation; collapse is a
/// SwiftUI content animation, after which the panel is ordered out so it stops covering the screen.
@MainActor
final class ShelfWindowController {
    private let panel: ShelfPanel
    private let triggerWindow: NSPanel
    private let store: ShelfStore
    private let uiState: ShelfUIState

    private var screenObserver: NSObjectProtocol?
    private var collapseTask: Task<Void, Never>?
    private var hideTask: Task<Void, Never>?

    private static let collapseDelay: Duration = .milliseconds(350)
    private static let hideAfterCollapse: Duration = .milliseconds(420)

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

    // MARK: - Public control (used by the in-shelf menu later)

    func show() {
        expand()
    }

    func hide() {
        collapseNow()
    }

    // MARK: - Configuration

    private func configurePanel() {
        let tracker = MouseTrackingView(acceptsDrag: false)
        tracker.frame = CGRect(origin: .zero, size: NotchGeometry.panelSize)
        tracker.onMouseEntered = { [weak self] in self?.expand() }
        tracker.onMouseExited = { [weak self] in self?.scheduleCollapse() }

        let hosting = NSHostingView(rootView: ShelfView(
            store: store,
            uiState: uiState
        ) { [weak self] in self?.hide() })
        hosting.frame = tracker.bounds
        hosting.autoresizingMask = [.width, .height]
        tracker.addSubview(hosting)
        panel.contentView = tracker
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
        tracker.onDragExited = { [weak self] in self?.scheduleCollapse() }
        triggerWindow.contentView = tracker
    }

    // MARK: - Activation

    private func expand() {
        cancelCollapse()
        hideTask?.cancel()
        positionPanel()
        panel.orderFrontRegardless()
        uiState.isExpanded = true
    }

    /// collapse after a short delay once the cursor leaves; cancelled on re-entry, and suppressed
    /// while a drag is hovering the shelf so it never collapses mid-drop (spec §8.1, §8.2, §22.2).
    private func scheduleCollapse() {
        guard !uiState.isDragOver else { return }
        collapseTask?.cancel()
        collapseTask = Task { [weak self] in
            try? await Task.sleep(for: Self.collapseDelay)
            guard !Task.isCancelled, let self, !uiState.isDragOver else { return }
            collapseNow()
        }
    }

    private func cancelCollapse() {
        collapseTask?.cancel()
        collapseTask = nil
    }

    private func collapseNow() {
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
        guard let screen = NSScreen.main else { return nil }
        return NotchGeometry.metrics(for: screen)
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
