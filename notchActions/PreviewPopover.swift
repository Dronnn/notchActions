//
//  PreviewPopover.swift
//  notchActions
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import AppKit
import SwiftUI

// MARK: - PreviewPopover

/// presents the hover preview in a custom NSPopover whose behavior is `.applicationDefined`. unlike
/// swiftui's `.popover` (a `.transient` NSPopover), it does NOT install the global event monitor that
/// eats the first outside mouse-down, so a slot stays draggable/clickable while the preview is open — the
/// drag then starts, the caller clears `info`, and this closes the popover so the drop can land. it is a
/// normal interactive window, so hover-to-scroll the preview still works (spec §20, §20.6).
struct PreviewPopover: NSViewRepresentable {
    /// the preview to show; nil closes the popover.
    let info: PreviewInfo?
    let onOpen: (URL) -> Void
    let onCopy: () -> Void
    /// forwarded from the preview's own hover so the dismiss grace (cursor traveling onto the popover) and
    /// the shelf's "over the shelf" hover monitor keep working.
    let onPreviewHover: (Bool) -> Void

    func makeNSView(context: Context) -> NSView {
        // a tiny transparent anchor that lives on the slot; the popover is shown relative to it.
        let anchor = NSView(frame: .zero)
        context.coordinator.anchor = anchor
        return anchor
    }

    func updateNSView(_: NSView, context: Context) {
        context.coordinator.update(
            info: info,
            onOpen: onOpen,
            onCopy: onCopy,
            onPreviewHover: onPreviewHover
        )
    }

    static func dismantleNSView(_: NSView, coordinator: Coordinator) {
        coordinator.close()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    // MARK: - Coordinator

    @MainActor
    final class Coordinator: NSObject, NSPopoverDelegate {
        weak var anchor: NSView?
        private let popover = NSPopover()
        /// the id currently shown, so the same info never re-triggers a show/close loop.
        private var shownInfoID: PreviewInfo.ID?

        override init() {
            super.init()
            // applicationDefined does not auto-dismiss on outside clicks and does not steal mouse-down.
            popover.behavior = .applicationDefined
            popover.animates = true
            popover.delegate = self
            // match the dark shelf chrome.
            popover.appearance = NSAppearance(named: .darkAqua)
        }

        func update(
            info: PreviewInfo?,
            onOpen: @escaping (URL) -> Void,
            onCopy: @escaping () -> Void,
            onPreviewHover: @escaping (Bool) -> Void
        ) {
            guard let info else {
                close()
                return
            }
            // already showing this exact preview: nothing to do (avoids a re-show loop).
            if popover.isShown, shownInfoID == info.id {
                return
            }
            let content = ShelfPreviewView(info: info, onOpen: onOpen, onCopy: onCopy)
                .onHover { onPreviewHover($0) }
            popover.contentViewController = NSHostingController(rootView: content)
            shownInfoID = info.id

            guard let anchor, anchor.window != nil else { return }
            // show above the slot (popover on the view's top edge), matching the old arrowEdge: .bottom.
            popover.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: .maxY)
        }

        func close() {
            shownInfoID = nil
            if popover.isShown {
                popover.performClose(nil)
            }
        }
    }
}
