//
//  ShelfPreviewView.swift
//  notchActions
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import SwiftUI

// MARK: - ShelfPreviewView

/// the hover-preview popover: a clickable thumbnail, a scrollable text snippet, a folder info table, or
/// a list of a bundle's files; with a top-right copy button (spec §20, §20.6). text/list scroll in place.
struct ShelfPreviewView: View {
    let info: PreviewInfo
    let onOpen: (URL) -> Void
    let onCopy: () -> Void

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
            if !info.files.isEmpty {
                BundleFileList(files: info.files, onOpen: onOpen)
            } else if let thumbnail = info.thumbnail {
                Button {
                    if let url = info.previewURL { onOpen(url) }
                } label: {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 360, maxHeight: 280)
                        .clipShape(.rect(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open \(info.name)")
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
        .overlay(alignment: .topTrailing) {
            Button(action: onCopy) {
                Image(systemName: "doc.on.clipboard.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.55))
                    .font(.body)
            }
            .buttonStyle(.plain)
            .padding(8)
            .accessibilityLabel("Copy \(info.name) to clipboard")
        }
    }
}

// MARK: - BundleFileList

/// a scrollable list of a bundle's files; each row is a button that opens that one file (spec §20.6).
private struct BundleFileList: View {
    let files: [PreviewFileEntry]
    let onOpen: (URL) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(files) { file in
                    Button {
                        onOpen(file.url)
                    } label: {
                        HStack(spacing: 8) {
                            if let icon = file.icon {
                                Image(nsImage: icon)
                                    .resizable()
                                    .frame(width: 24, height: 24)
                            }
                            Text(file.name)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer(minLength: 0)
                        }
                        .font(.callout)
                        .contentShape(.rect)
                        .padding(.vertical, 3)
                        .padding(.horizontal, 6)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open \(file.name)")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: 380, maxHeight: 280)
    }
}
