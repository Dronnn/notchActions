//
//  Log.swift
//  notchActions
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import Foundation
import os

// MARK: - Log

/// os.Logger categories for lightweight development logging (spec §35).
/// dynamic values that aid debugging (paths, names) are logged with `privacy: .public`
/// at the call site; never surface these logs to the user.
enum Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "notchActions"

    static let lifecycle = Logger(subsystem: subsystem, category: "lifecycle")
    static let dragdrop = Logger(subsystem: subsystem, category: "dragdrop")
    static let persistence = Logger(subsystem: subsystem, category: "persistence")
    static let clipboard = Logger(subsystem: subsystem, category: "clipboard")
    static let geometry = Logger(subsystem: subsystem, category: "geometry")
}
