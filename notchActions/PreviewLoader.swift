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

// MARK: - PreviewFileEntry

/// one listed file inside a bundle preview: an icon, a name, and the live url so a row can open it (spec §20.6).
struct PreviewFileEntry: Identifiable, Equatable {
    let id = UUID()
    var icon: NSImage?
    var name: String
    var url: URL
}

// MARK: - PreviewInfo

struct PreviewInfo: Identifiable, Equatable {
    let id = UUID()
    var icon: NSImage?
    var thumbnail: NSImage?
    var name: String
    var textSnippet: String?
    var rows: [PreviewRow]
    /// the single file the thumbnail/snippet describes, so clicking the image opens it (spec §20.6).
    var previewURL: URL?
    /// non-empty only for a multi-file bundle; each row opens its own file (spec §20.6).
    var files: [PreviewFileEntry] = []
}

// MARK: - PreviewLoader

/// builds a hover preview: a Quick Look thumbnail for files, a scrollable snippet for text/markdown,
/// or an info table for folders; a multi-file bundle lists its files instead (spec §20, §20.6, §37.9, §42).
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
        return PreviewInfo(
            icon: icon,
            thumbnail: thumbnail,
            name: name,
            textSnippet: snippet,
            rows: rows,
            previewURL: url
        )
    }

    /// a multi-file bundle preview: just a header + a list of files (icon + name), each opening its own
    /// file. `entries` pairs every still-resolving bundle file with its live url, in bundle order (spec §20.6).
    static func loadBundle(name: String, entries: [(file: ShelfFile, url: URL)]) -> PreviewInfo {
        let files = entries.map { entry in
            PreviewFileEntry(
                icon: IconProvider.icon(for: entry.url, broken: false, size: 24),
                name: entry.file.displayName,
                url: entry.url
            )
        }
        return PreviewInfo(icon: nil, thumbnail: nil, name: name, textSnippet: nil, rows: [], files: files)
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
