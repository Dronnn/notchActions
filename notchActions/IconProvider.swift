//
//  IconProvider.swift
//  notchActions
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import AppKit

// MARK: - IconProvider

/// native file / folder / app icons via NSWorkspace, with a small in-memory cache (spec §19, §37.8).
/// broken or missing items get a warning symbol instead of a generic placeholder.
@MainActor
enum IconProvider {
    private static var cache: [String: NSImage] = [:]
    private static let cacheLimit = 64

    static func icon(for url: URL?, broken: Bool, size: CGFloat) -> NSImage {
        guard !broken, let url else {
            return brokenIcon(size: size)
        }
        let key = "\(url.path(percentEncoded: false))-\(Int(size))"
        if let cached = cache[key] {
            return cached
        }
        let image = NSWorkspace.shared.icon(forFile: url.path(percentEncoded: false))
        image.size = NSSize(width: size, height: size)
        store(image, for: key)
        return image
    }

    private static func brokenIcon(size: CGFloat) -> NSImage {
        let symbol = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: "broken item")
            ?? NSImage()
        symbol.size = NSSize(width: size, height: size)
        return symbol
    }

    private static func store(_ image: NSImage, for key: String) {
        // crude eviction: the shelf holds at most a handful of icons, so the cap is a safety net.
        if cache.count >= cacheLimit {
            cache.removeAll()
        }
        cache[key] = image
    }
}
