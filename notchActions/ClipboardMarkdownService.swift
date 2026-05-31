//
//  ClipboardMarkdownService.swift
//  notchActions
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import AppKit
import os

// MARK: - ClipboardError

enum ClipboardError: Error {
    case empty
    case unsupported
    case noSlot
    case writeFailed
}

// MARK: - ClipboardMarkdownService

/// turns the current clipboard text into a real .md file in local storage and adds it to the shelf
/// as a normal item (only its kind differs) (spec §18, §39).
@MainActor
enum ClipboardMarkdownService {
    static func makeNote(addingTo store: ShelfStore) -> Result<Int, ClipboardError> {
        // pick the free slot before writing the file, so a full shelf never leaves an orphan note.
        guard let slot = store.firstEmptySlot else {
            return .failure(.noSlot)
        }
        let url: URL
        switch writeClipboardNote() {
        case let .success(written):
            url = written
        case let .failure(error):
            return .failure(error)
        }
        store.appendNote(url: url, isAppCreated: true, to: slot)
        Log.clipboard.info("created clipboard note at slot \(slot)")
        return .success(slot)
    }

    /// writes the current clipboard to a new app-created .md note in the notes dir and returns its url,
    /// without touching the shelf; the caller decides which slot it lands in (spec §29.2, §38.3).
    static func writeClipboardNote() -> Result<URL, ClipboardError> {
        guard let text = clipboardText(), !text.isEmpty else {
            return .failure(.empty)
        }
        do {
            let url = try writeNote(text: text)
            return .success(url)
        } catch {
            Log.clipboard.error("clipboard note write failed: \(error.localizedDescription, privacy: .public)")
            return .failure(.writeFailed)
        }
    }

    /// plain text if present, otherwise rich text (rtf/html) flattened to plain text (spec §18).
    private static func clipboardText() -> String? {
        let pasteboard = NSPasteboard.general
        if let string = pasteboard.string(forType: .string), !string.isEmpty {
            return string
        }
        if
            let rtf = pasteboard.data(forType: .rtf),
            let attributed = NSAttributedString(rtf: rtf, documentAttributes: nil)
        {
            return attributed.string
        }
        if
            let html = pasteboard.data(forType: .html),
            let attributed = NSAttributedString(html: html, documentAttributes: nil)
        {
            return attributed.string
        }
        return nil
    }

    /// writes utf-8, preserves line breaks, atomic; names like "Clipboard Note 2026-05-31 14-30.md"
    /// with " 1", " 2"… disambiguation if needed (spec §39).
    private static func writeNote(text: String) throws -> URL {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH-mm"
        let baseName = "Clipboard Note \(formatter.string(from: .now))"
        let url = uniqueURL(in: AppPaths.clipboardNotesDir, baseName: baseName, fileExtension: "md")
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private static func uniqueURL(in directory: URL, baseName: String, fileExtension: String) -> URL {
        let fileManager = FileManager.default
        var candidate = directory.appending(path: "\(baseName).\(fileExtension)", directoryHint: .notDirectory)
        var counter = 1
        while fileManager.fileExists(atPath: candidate.path(percentEncoded: false)) {
            candidate = directory.appending(
                path: "\(baseName) \(counter).\(fileExtension)",
                directoryHint: .notDirectory
            )
            counter += 1
        }
        return candidate
    }
}
