//
//  AppController.swift
//  notchActions
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import AppKit
import os

// MARK: - AppController

/// app startup and global coordination (spec §37.1). notchActions is fully hidden: no dock icon
/// (accessory policy + LSUIElement) and no menu-bar item; the shelf appears only when the cursor
/// or a file-drag reaches the notch, and quit lives in the shelf's own menu.
final class AppController: NSObject, NSApplicationDelegate {
    let store = ShelfStore()
    private let uiState = ShelfUIState()
    private let layoutConfig = LayoutConfigStore()
    private var shelfWindowController: ShelfWindowController?
    private var layoutSettingsWindowController: LayoutSettingsWindowController?

    func applicationDidFinishLaunching(_: Notification) {
        // single instance: if another copy is already running, this one must win nothing — exit before any
        // trigger window / shelf is created, so two invisible triggers never fight over mouse events and two
        // stores never write the same shelf.json (spec §37.1).
        guard !anotherInstanceIsRunning() else {
            Log.lifecycle.info("another notchActions instance is already running; terminating this one")
            existingInstance()?.activate()
            NSApp.terminate(nil)
            return
        }

        Log.lifecycle.info("notchActions launched")
        NSApp.setActivationPolicy(.accessory)
        // the settings window edits the same layout config the shelf observes, so edits persist and the
        // shelf re-lays-out on its next summon.
        let settings = LayoutSettingsWindowController(layoutConfig: layoutConfig)
        layoutSettingsWindowController = settings
        shelfWindowController = ShelfWindowController(
            store: store,
            uiState: uiState,
            layoutConfig: layoutConfig
        ) { [weak settings] in
            settings?.show()
        }
    }

    // MARK: - Single instance

    /// true when another running app shares our bundle id but is a different process.
    private func anotherInstanceIsRunning() -> Bool {
        existingInstance() != nil
    }

    /// the other already-running notchActions instance, if any: same bundle id, different pid than ours.
    private func existingInstance() -> NSRunningApplication? {
        let bundleID = Bundle.main.bundleIdentifier
        let currentPID = ProcessInfo.processInfo.processIdentifier
        return NSWorkspace.shared.runningApplications.first { app in
            app.bundleIdentifier == bundleID
                && app != .current
                && app.processIdentifier != currentPID
        }
    }
}
