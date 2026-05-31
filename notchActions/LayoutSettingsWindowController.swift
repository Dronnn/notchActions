//
//  LayoutSettingsWindowController.swift
//  notchActions
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import AppKit
import SwiftUI

// MARK: - LayoutSettingsWindowController

/// owns one reusable floating window that hosts `LayoutSettingsView`. the shelf is an accessory app with
/// no dock icon, so while the settings window is open the activation policy is temporarily raised to
/// `.regular` — that lets the window take keyboard focus for the text fields — and dropped back to
/// `.accessory` once it closes, so the dock icon only ever appears while configuring the layout.
@MainActor
final class LayoutSettingsWindowController: NSObject, NSWindowDelegate {
    private let layoutConfig: LayoutConfigStore
    private var window: NSWindow?
    /// the app that was frontmost before the settings window opened, so focus can be returned to it on
    /// close without hiding our own windows (hiding would order out the always-on notch trigger).
    private var previousApp: NSRunningApplication?

    init(layoutConfig: LayoutConfigStore) {
        self.layoutConfig = layoutConfig
    }

    // MARK: - Public control

    func show() {
        let isFreshOpen = window == nil || !(window?.isVisible ?? false)
        // capture the previously-frontmost app only on a fresh open, and never store ourselves, so a
        // re-show while the window is already open can't clobber the saved app with notchActions.
        if isFreshOpen {
            let frontmost = NSWorkspace.shared.frontmostApplication
            previousApp = frontmost == .current ? nil : frontmost
        }
        // raise to a regular app so the window can become key and the text fields can take focus.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()

        let window = window ?? makeWindow()
        self.window = window
        if isFreshOpen {
            window.center()
        }
        window.makeKeyAndOrderFront(nil)
    }

    // MARK: - Window

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "notchActions Layout"
        window.isReleasedWhenClosed = false
        window.delegate = self

        let content = LayoutSettingsView(layoutConfig: layoutConfig) { [weak self] in
            self?.window?.close()
        }
        // a hosting controller makes the window auto-size to the SwiftUI ideal size and track it both ways,
        // so adding rows grows the window and removing rows shrinks it (a direct NSHostingView with
        // preferredContentSize does not resize the window reliably).
        let hostingController = NSHostingController(rootView: content)
        window.contentViewController = hostingController
        return window
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_: Notification) {
        // hand focus back to the previously-frontmost app without hiding ourselves: NSApp.hide(nil) would
        // order out the always-on notch trigger window and permanently break hover-to-summon. never
        // reactivate ourselves. uses apple's cooperative-activation two-step (macOS 14): yield first, then
        // drop to accessory, then let the other app request activation.
        if let previousApp, previousApp != .current {
            NSApp.yieldActivation(to: previousApp)
            NSApp.setActivationPolicy(.accessory)
            previousApp.activate()
        } else {
            // drop back to accessory so the dock icon disappears once configuration is done.
            NSApp.setActivationPolicy(.accessory)
        }
        previousApp = nil
    }
}
