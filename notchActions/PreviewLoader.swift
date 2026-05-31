//
//  PreviewLoader.swift
//  notchActions
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import AppKit
import QuickLookThumbnailing
import UniformTypeIdentifiers

// MARK: - PreviewRow

struct PreviewRow: Identifiable, Equatable {
    let id = UUID()
    let label: String
    let value: String
}

// MARK: - PreviewInfo

struct PreviewInfo: Identifiable, Equatable {
    let id = UUID()
    var icon: NSImage?
    var thumbnail: NSImage?
    var name: String
    var textSnippet: String?
    var rows: [PreviewRow]
}

// MARK: - PreviewLoader

/// builds a hover preview: a Quick Look thumbnail for files, a scrollable snippet for text/markdown,
/// or an info table for folders; plus name + kind + size/items + modified date (spec §20, §37.9, §42).
@MainActor
enum PreviewLoader {
    static func load(url: URL, kind: ShelfItemKind, name: String, icon: NSImage) async -> PreviewInfo {
        let values = try? url.resourceValues(forKeys: [
            .fileSizeKey, .contentTypeKey, .isDirectoryKey, .contentModificationDateKey
        ])
        let isDirectory = values?.isDirectory ?? (kind == .folder)

        var rows: [PreviewRow] = [
            PreviewRow(label: "Kind", value: values?.contentType?.localizedDescription ?? (isDirectory
                    ? "Folder"
                    : "File"))
        ]
        if isDirectory {
            if let count = try? FileManager.default.contentsOfDirectory(atPath: url.path(percentEncoded: false)).count {
                rows.append(PreviewRow(label: "Items", value: "\(count)"))
            }
        } else if let size = values?.fileSize {
            rows.append(PreviewRow(
                label: "Size",
                value: ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
            ))
        }
        if let modified = values?.contentModificationDate {
            rows.append(PreviewRow(label: "Modified", value: modified.formatted(date: .abbreviated, time: .shortened)))
        }

        let isText = values?.contentType?.conforms(to: .text) ?? false
        let snippet = (kind == .markdownNote || isText) ? textSnippet(for: url) : nil
        // folders show the info table + small icon; text shows a scrollable snippet; else a thumbnail.
        let thumbnail = (isDirectory || snippet != nil) ? nil : await makeThumbnail(for: url)
        return PreviewInfo(icon: icon, thumbnail: thumbnail, name: name, textSnippet: snippet, rows: rows)
    }

    private static func makeThumbnail(for url: URL) async -> NSImage? {
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: 360, height: 280),
            scale: scale,
            representationTypes: .all
        )
        return await withCheckedContinuation { continuation in
            QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { representation, _ in
                continuation.resume(returning: representation?.nsImage)
            }
        }
    }

    private static func textSnippet(for url: URL) -> String? {
        guard let data = try? Data(contentsOf: url, options: [.mappedIfSafe]) else { return nil }
        return String(data: data.prefix(8_000), encoding: .utf8)
    }
}
