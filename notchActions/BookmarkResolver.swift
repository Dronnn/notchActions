//
//  BookmarkResolver.swift
//  notchActions
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import Foundation
import os

// MARK: - BookmarkResolver

/// security-scoped bookmark creation/resolution, scoped access, and url classification (spec §25).
enum BookmarkResolver {
    // MARK: - Bookmarks

    static func makeBookmark(for url: URL) throws -> Data {
        try url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
    }

    /// resolves bookmark data back to a url; nil on failure (spec §25).
    static func resolve(_ data: Data) -> (url: URL, isStale: Bool)? {
        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            return (url, isStale)
        } catch {
            Log.persistence.error("bookmark resolve failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    // MARK: - Classification

    static func classify(_ url: URL) -> ShelfItemKind {
        if url.pathExtension.lowercased() == "app" {
            return .application
        }
        let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
        return isDirectory ? .folder : .file
    }

    // MARK: - Scoped Access

    /// runs `body` with the security scope started; a false start in a non-sandboxed app
    /// must not block access, so `body` still runs either way (spec §25).
    @discardableResult
    static func withAccess<T>(_ url: URL, _ body: (URL) throws -> T) rethrows -> T {
        let didStart = url.startAccessingSecurityScopedResource()
        defer {
            if didStart {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try body(url)
    }
}
