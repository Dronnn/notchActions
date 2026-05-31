//
//  SlotBundleDragSource.swift
//  notchActions
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import AppKit
import SwiftUI

// MARK: - SlotBundleDragSource

/// transparent overlay that lets a multi-file slot drag out ALL of its files as separate dragging
/// items (one file url each), so dropping into Finder or another app yields every file in the bundle
/// (spec §15, §38). a single-file slot keeps the plain SwiftUI `.onDrag` path. a click without a drag
/// is forwarded to `onClick` so single-click still opens the whole bundle (spec §12).
struct SlotBundleDragSource: NSViewRepresentable {
    let urls: [URL]
    let sourceSlot: Int
    let onClick: () -> Void

    func makeNSView(context _: Context) -> DragSourceView {
        let view = DragSourceView()
        view.urls = urls
        view.sourceSlot = sourceSlot
        view.onClick = onClick
        return view
    }

    func updateNSView(_ view: DragSourceView, context _: Context) {
        view.urls = urls
        view.sourceSlot = sourceSlot
        view.onClick = onClick
    }

    // MARK: - DragSourceView

    final class DragSourceView: NSView, NSDraggingSource {
        var urls: [URL] = []
        var sourceSlot = 0
        var onClick: (() -> Void)?

        private var mouseDownPoint: NSPoint?

        func draggingSession(
            _: NSDraggingSession,
            sourceOperationMaskFor _: NSDraggingContext
        ) -> NSDragOperation {
            [.copy, .generic]
        }

        override func mouseDown(with event: NSEvent) {
            mouseDownPoint = event.locationInWindow
        }

        override func mouseDragged(with event: NSEvent) {
            guard let start = mouseDownPoint, !urls.isEmpty else { return }
            let delta = hypot(event.locationInWindow.x - start.x, event.locationInWindow.y - start.y)
            // small threshold so a click never starts a drag.
            guard delta > 3 else { return }
            mouseDownPoint = nil
            beginBundleDrag(with: event)
        }

        override func mouseUp(with _: NSEvent) {
            // a press without a drag opens the bundle (matches the single-file button click).
            if mouseDownPoint != nil {
                mouseDownPoint = nil
                onClick?()
            }
        }

        /// one dragging item per resolving file url; the first item also carries the private SlotDrag
        /// payload so an internal drop onto another slot still swaps (spec §11, §15).
        private func beginBundleDrag(with event: NSEvent) {
            var items: [NSDraggingItem] = []
            for (offset, url) in urls.enumerated() {
                // the first item also carries the private SlotDrag type so an internal drop swaps.
                let writer: NSPasteboardWriting = offset == 0 ? pasteboardItem(for: url) : url as NSURL
                let item = NSDraggingItem(pasteboardWriter: writer)
                let icon = NSWorkspace.shared.icon(forFile: url.path(percentEncoded: false))
                // fan the drag images out slightly so the count reads as a stack.
                let origin = NSPoint(x: CGFloat(offset) * 6, y: -CGFloat(offset) * 6)
                let frame = NSRect(origin: origin, size: NSSize(width: 48, height: 48))
                item.setDraggingFrame(frame, contents: icon)
                items.append(item)
            }
            beginDraggingSession(with: items, event: event, source: self)
        }

        /// a pasteboard item that both writes the real file url (so Finder gets the file) and tags the
        /// source slot via the private SlotDrag type (so an internal drop onto another slot swaps).
        private func pasteboardItem(for url: URL) -> NSPasteboardItem {
            let item = NSPasteboardItem()
            item.setString(url.absoluteString, forType: .fileURL)
            item.setData(SlotDrag.data(for: sourceSlot), forType: NSPasteboard.PasteboardType(SlotDrag.typeID))
            return item
        }
    }
}
