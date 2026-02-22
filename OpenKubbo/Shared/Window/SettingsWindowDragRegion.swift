import AppKit
import SwiftUI

struct SettingsWindowDragRegion: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        SettingsDragRegionNSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class SettingsDragRegionNSView: NSView {
    override func resetCursorRects() {
        super.resetCursorRects()
        discardCursorRects()
        addCursorRect(bounds, cursor: .openHand)
    }

    override func mouseDown(with event: NSEvent) {
        NSCursor.closedHand.push()
        defer { NSCursor.pop() }
        window?.performDrag(with: event)
    }
}
