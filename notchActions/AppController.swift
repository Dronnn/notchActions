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
        Log.lifecycle.info("notchActions launched")
        NSApp.setActivationPolicy(.accessory)
        // the settings window edits the SAME layout config the shelf observes, so edits persist and the
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
}
