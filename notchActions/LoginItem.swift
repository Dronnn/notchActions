//
//  LoginItem.swift
//  notchActions
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import os
import ServiceManagement

// MARK: - LoginItem

/// registers/unregisters notchActions as a launch-at-login item via SMAppService (spec §22.1).
@MainActor
enum LoginItem {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            Log.lifecycle.info("launch at login set to \(enabled)")
        } catch {
            Log.lifecycle.error("launch at login change failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
