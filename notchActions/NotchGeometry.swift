//
//  NotchGeometry.swift
//  notchActions
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import AppKit

// MARK: - NotchMetrics

/// describes the notch (real or virtual) on a screen, in AppKit coordinates (origin bottom-left).
struct NotchMetrics {
    let screen: NSScreen
    let notchRect: CGRect
    let hasRealNotch: Bool
}

// MARK: - NotchGeometry

/// notch detection and panel / trigger frame math (spec §5, §6, §7).
/// v1 targets the main display; the screen parameter keeps multi-display support open (§5.3).
enum NotchGeometry {
    /// expanded panel size (spec §6; locked 440 x 150).
    static var panelSize: CGSize {
        ShelfLayout.panelSize
    }

    private static let virtualNotchSize = CGSize(width: 200, height: 32)
    private static let fallbackNotchWidth: CGFloat = 200

    /// builds metrics for a screen: a real notch when there is a top safe-area inset,
    /// otherwise a virtual notch centered at the top edge (spec §5.1, §5.2).
    static func metrics(for screen: NSScreen) -> NotchMetrics {
        let frame = screen.frame
        let topInset = screen.safeAreaInsets.top
        if topInset > 0 {
            return NotchMetrics(
                screen: screen,
                notchRect: realNotchRect(for: screen, height: topInset),
                hasRealNotch: true
            )
        }
        let virtualRect = CGRect(
            x: frame.midX - virtualNotchSize.width / 2,
            y: frame.maxY - virtualNotchSize.height,
            width: virtualNotchSize.width,
            height: virtualNotchSize.height
        )
        return NotchMetrics(screen: screen, notchRect: virtualRect, hasRealNotch: false)
    }

    /// always-on hover/drag trigger area: exactly the notch (spec §8.1).
    static func collapsedTriggerRect(_ metrics: NotchMetrics) -> CGRect {
        // exactly the notch (dead space): no widening and no downward lip, so it never covers
        // menu-bar items or swallows clicks just below the notch.
        metrics.notchRect
    }

    /// expanded panel: fixed size, centered on the notch, top flush with the screen top and
    /// growing downward, clamped horizontally to the visible frame (spec §6, §9).
    static func expandedPanelRect(_ metrics: NotchMetrics) -> CGRect {
        let frame = metrics.screen.frame
        let visible = metrics.screen.visibleFrame
        let originY = frame.maxY - panelSize.height
        let unclampedX = metrics.notchRect.midX - panelSize.width / 2
        let clampedX = min(max(unclampedX, visible.minX), visible.maxX - panelSize.width)
        return CGRect(x: clampedX, y: originY, width: panelSize.width, height: panelSize.height)
    }

    // MARK: - Helpers

    /// notch width comes from the gap between the two auxiliary menu-bar areas; falls back to a
    /// centered ~200pt span if the system does not report them (spec §5.1).
    private static func realNotchRect(for screen: NSScreen, height: CGFloat) -> CGRect {
        let frame = screen.frame
        let topY = frame.maxY - height
        if
            let left = screen.auxiliaryTopLeftArea,
            let right = screen.auxiliaryTopRightArea
        {
            let notchWidth = right.minX - left.maxX
            if notchWidth > 0 {
                return CGRect(x: left.maxX, y: topY, width: notchWidth, height: height)
            }
        }
        return CGRect(x: frame.midX - fallbackNotchWidth / 2, y: topY, width: fallbackNotchWidth, height: height)
    }
}
