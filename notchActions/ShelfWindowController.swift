//
//  ShelfWindowController.swift
//  notchActions
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import AppKit
import Observation
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
    private let layoutConfig: LayoutConfigStore
    private let onConfigureLayout: () -> Void

    private var screenObserver: NSObjectProtocol?
    private var hoverMonitorTask: Task<Void, Never>?
    private var hideTask: Task<Void, Never>?
    private var keyMonitor: Any?

    private static let collapseDelay: Duration = .milliseconds(350)
    private static let hideAfterCollapse: Duration = .milliseconds(420)
    private static let pollInterval: Duration = .milliseconds(120)
    private static let keepOpenMargin: CGFloat = 8

    // MARK: - Lifecycle

    init(
        store: ShelfStore,
        uiState: ShelfUIState,
        layoutConfig: LayoutConfigStore,
        onConfigureLayout: @escaping () -> Void
    ) {
        self.store = store
        self.uiState = uiState
        self.layoutConfig = layoutConfig
        self.onConfigureLayout = onConfigureLayout

        let grid = Self.grid(for: layoutConfig.config)
        store.slotCount = grid.totalSlotCount

        panel = ShelfPanel(contentRect: Self.panelFrame(for: grid) ?? CGRect(origin: .zero, size: grid.panelSize))
        triggerWindow = NSPanel(
            contentRect: Self.triggerFrame() ?? .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        configurePanel()
        configureTrigger()
        observeScreenChanges()
        observeLayoutConfig()
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
        rebuildHostedView()
    }

    /// (re)installs the hosted ShelfView with the current notch width so the rendered grid matches the
    /// active notch screen; called at launch and whenever the layout or screen geometry changes (spec §10.4).
    private func rebuildHostedView() {
        let notchWidth = Self.notchScreen().map { NotchGeometry.notchWidth(for: $0) } ?? 0
        panel.contentView = NSHostingView(rootView: ShelfView(
            store: store,
            uiState: uiState,
            layoutConfig: layoutConfig,
            notchWidth: notchWidth,
            onHide: { [weak self] in self?.hide() },
            onConfigureLayout: onConfigureLayout
        ))
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
        // clear any drag-source left over from a previous open's drag-out, so it can never be mistaken for
        // an internal rearrange on a later external drop.
        uiState.draggingSourceSlot = nil
        positionPanel()
        // become key (without activating the app) so cmd-V reaches us while merely hovering.
        panel.makeKeyAndOrderFront(nil)
        uiState.isExpanded = true
        startHoverMonitor()
        installKeyMonitor()
    }

    /// capture cmd-V while the shelf is open (even on hover, no click) to paste the clipboard as a
    /// markdown note into a free slot (spec §18, §28).
    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard
                let self,
                event.modifierFlags.contains(.command),
                event.charactersIgnoringModifiers == "v"
            else { return event }
            ShelfActions.pasteClipboard(store: store, uiState: uiState)
            return nil
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
        keyMonitor = nil
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
        return panelArea.contains(cursor) || triggerWindow.frame.contains(cursor) || uiState.isPreviewing
    }

    private func collapseNow() {
        hoverMonitorTask?.cancel()
        hoverMonitorTask = nil
        removeKeyMonitor()
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
        guard let frame = Self.panelFrame(for: activeGrid()) else { return }
        panel.setFrame(frame, display: true)
    }

    // MARK: - Live layout config

    /// re-arms after each change so the panel re-lays-out and the slot count tracks the grid whenever
    /// the user edits rows/columns from the gear menu (spec §10.4, §22.5).
    private func observeLayoutConfig() {
        withObservationTracking {
            _ = layoutConfig.config
        } onChange: {
            Task { @MainActor [weak self] in
                self?.applyLayoutConfig()
            }
        }
    }

    private func applyLayoutConfig() {
        let total = activeGrid().totalSlotCount
        // an explicit user capacity change can shrink the grid: pull out-of-range items back in before the
        // slot count drops, so a shrink does not strand items off-screen (spec §10.4, §22.5).
        store.repack(into: total)
        store.slotCount = total
        rebuildHostedView()
        positionPanel()
        observeLayoutConfig()
    }

    private func activeGrid() -> ShelfGrid {
        Self.grid(for: layoutConfig.config)
    }

    // MARK: - Geometry

    private static func grid(for config: ShelfLayoutConfig) -> ShelfGrid {
        let notchWidth = notchScreen().map { NotchGeometry.notchWidth(for: $0) } ?? 0
        return ShelfGrid(config: config, notchWidth: notchWidth)
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

    private static func panelFrame(for grid: ShelfGrid) -> CGRect? {
        guard let metrics = metrics() else { return nil }
        return NotchGeometry.expandedPanelRect(metrics, panelSize: grid.panelSize)
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
                self?.applyScreenChange()
            }
        }
    }

    /// the notch screen (or its notch width) may have changed, so recompute the active grid, refresh the
    /// slot count and the hosted view's notch width, and reposition. this is NOT a user capacity change,
    /// so it never repacks items (spec §10.4). the shelf still anchors to the built-in notched display.
    private func applyScreenChange() {
        store.slotCount = activeGrid().totalSlotCount
        rebuildHostedView()
        positionWindows()
    }
}
