//
//  SlotIconStack.swift
//  notchActions
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import SwiftUI

// MARK: - SlotIconStack

/// the slot's icon: a single icon for a one-file bundle, or fanned/stacked thumbnails plus a count
/// badge for a multi-file bundle (spec §10.3, §38.1). a single-file bundle renders exactly as before.
struct SlotIconStack: View {
    /// resolving file urls for the bundle, in bundle order; the first drives the front icon.
    let urls: [URL]
    let fileCount: Int

    /// at most three layers read as a stack; the front layer is the primary file, drawn last/on top.
    private var fanURLs: [URL] {
        Array(urls.prefix(3))
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if fanURLs.isEmpty {
                // whole bundle unresolved → the same warning icon a broken single slot shows today.
                Image(nsImage: IconProvider.icon(for: nil, broken: true, size: ShelfLayout.iconSize))
                    .resizable()
                    .frame(width: ShelfLayout.iconSize, height: ShelfLayout.iconSize)
            } else {
                ZStack {
                    ForEach(fanURLs.enumerated().reversed(), id: \.offset) { layer, url in
                        Image(nsImage: IconProvider.icon(for: url, broken: false, size: ShelfLayout.iconSize))
                            .resizable()
                            .frame(width: ShelfLayout.iconSize, height: ShelfLayout.iconSize)
                            .rotationEffect(.degrees(layer == 0 ? 0 : Double(layer) * 6))
                            .offset(x: CGFloat(layer) * 3, y: CGFloat(layer) * 3)
                            .shadow(color: .black.opacity(layer == 0 ? 0 : 0.25), radius: 1, y: 1)
                    }
                }
            }
            if fileCount > 1 {
                CountBadge(count: fileCount)
                    .offset(x: 6, y: 2)
            }
        }
        .frame(width: ShelfLayout.iconSize, height: ShelfLayout.iconSize)
    }
}

// MARK: - CountBadge

private struct CountBadge: View {
    let count: Int

    var body: some View {
        Text("\(count)")
            .font(.caption2)
            .bold()
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background {
                Capsule(style: .continuous)
                    .fill(Color.accentColor)
                    .overlay {
                        Capsule(style: .continuous)
                            .strokeBorder(.white.opacity(0.85), lineWidth: 1)
                    }
            }
            .accessibilityLabel("\(count) items")
    }
}
