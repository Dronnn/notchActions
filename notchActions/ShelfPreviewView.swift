//
//  ShelfPreviewView.swift
//  notchActions
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import SwiftUI

// MARK: - ShelfPreviewView

/// the small hover-preview popover content: a thumbnail or text snippet, the name, and type/size
/// (spec §20). kept compact and non-interactive.
struct ShelfPreviewView: View {
    let info: PreviewInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let snippet = info.textSnippet, !snippet.isEmpty {
                Text(snippet)
                    .font(.caption)
                    .lineLimit(6)
                    .frame(maxWidth: 240, alignment: .leading)
            } else if let image = info.image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 200, maxHeight: 150)
                    .clipShape(.rect(cornerRadius: 6))
            }
            Text(info.name)
                .font(.caption)
                .bold()
                .lineLimit(1)
            if !info.detail.isEmpty {
                Text(info.detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: 264)
    }
}
