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

// MARK: - PreviewInfo

struct PreviewInfo: Equatable {
    var image: NSImage?
    var name: String
    var detail: String
    var textSnippet: String?
}

// MARK: - PreviewLoader

/// builds a lightweight hover preview for an item: a Quick Look thumbnail (image/pdf/etc.), the
/// first lines for text & markdown, plus name + type + size; all off the main work, never blocking
/// (spec §20, §37.9, §42).
@MainActor
enum PreviewLoader {
    static func load(url: URL, kind: ShelfItemKind, name: String) async -> PreviewInfo {
        let detail = metaDescription(for: url)
        let snippet = (kind == .markdownNote || isText(url)) ? textSnippet(for: url) : nil
        let image = await thumbnail(for: url)
        return PreviewInfo(image: image, name: name, detail: detail, textSnippet: snippet)
    }

    private static func thumbnail(for url: URL) async -> NSImage? {
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: 200, height: 150),
            scale: scale,
            representationTypes: .all
        )
        return await withCheckedContinuation { continuation in
            QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { representation, _ in
                continuation.resume(returning: representation?.nsImage)
            }
        }
    }

    private static func metaDescription(for url: URL) -> String {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentTypeKey, .isDirectoryKey])
        var parts: [String] = []
        if let type = values?.contentType?.localizedDescription {
            parts.append(type)
        }
        if values?.isDirectory != true, let size = values?.fileSize {
            parts.append(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))
        }
        return parts.joined(separator: " · ")
    }

    private static func isText(_ url: URL) -> Bool {
        let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType
        return type?.conforms(to: .text) ?? false
    }

    private static func textSnippet(for url: URL) -> String? {
        guard let data = try? Data(contentsOf: url, options: [.mappedIfSafe]) else { return nil }
        guard let text = String(data: data.prefix(2_000), encoding: .utf8) else { return nil }
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).prefix(6)
        return lines.joined(separator: "\n")
    }
}
