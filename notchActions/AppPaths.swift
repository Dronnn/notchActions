//
//  AppPaths.swift
//  notchActions
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import Foundation
import os

// MARK: - AppPaths

/// human-readable storage locations under Application Support (spec §13, §39).
/// each accessor creates its directory on demand and logs on failure.
enum AppPaths {
    /// Application Support/notchActions
    static var supportDir: URL {
        let dir = URL.applicationSupportDirectory.appending(path: "notchActions", directoryHint: .isDirectory)
        ensureDirectory(dir)
        return dir
    }

    /// Application Support/notchActions/Clipboard Notes
    static var clipboardNotesDir: URL {
        let dir = supportDir.appending(path: "Clipboard Notes", directoryHint: .isDirectory)
        ensureDirectory(dir)
        return dir
    }

    /// Application Support/notchActions/shelf.json
    static var storeFile: URL {
        supportDir.appending(path: "shelf.json", directoryHint: .notDirectory)
    }

    private static func ensureDirectory(_ url: URL) {
        let fileManager = FileManager.default
        guard !fileManager.fileExists(atPath: url.path(percentEncoded: false)) else { return }
        do {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        } catch {
            Log.persistence.error(
                "failed to create \(url.path(percentEncoded: false), privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
        }
    }
}
