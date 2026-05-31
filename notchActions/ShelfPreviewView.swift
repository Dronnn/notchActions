//
//  ShelfPreviewView.swift
//  notchActions
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import SwiftUI

// MARK: - ShelfPreviewView

/// the hover-preview popover: a thumbnail, a scrollable text snippet, or a folder info table, with a
/// small icon + name header (spec §20). text is scrollable so it can be read in place.
struct ShelfPreviewView: View {
    let info: PreviewInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                if let icon = info.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 28, height: 28)
                }
                Text(info.name)
                    .font(.headline)
                    .lineLimit(1)
            }
            if let thumbnail = info.thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 360, maxHeight: 280)
                    .clipShape(.rect(cornerRadius: 8))
            } else if let snippet = info.textSnippet, !snippet.isEmpty {
                ScrollView {
                    Text(snippet)
                        .font(.callout)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: 380, maxHeight: 280)
            }
            if !info.rows.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(info.rows) { row in
                        HStack(spacing: 8) {
                            Text(row.label)
                                .foregroundStyle(.secondary)
                                .frame(width: 72, alignment: .leading)
                            Text(row.value)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        .font(.callout)
                    }
                }
            }
        }
        .padding(16)
        .frame(minWidth: 300, maxWidth: 440)
    }
}
