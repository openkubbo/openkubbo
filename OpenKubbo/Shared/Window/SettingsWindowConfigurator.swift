import AppKit
import ObjectiveC.runtime
import SwiftUI

struct SettingsWindowConfigurator: NSViewRepresentable {
    let targetSize: CGSize
    let minimumSize: CGSize
    let windowIdentifier: String
    let windowLevel: NSWindow.Level
    let onResolve: (NSWindow) -> Void

    private static var patchedWindowClasses: Set<ObjectIdentifier> = []

    init(
        targetSize: CGSize,
        minimumSize: CGSize = CGSize(width: 620, height: 520),
        windowIdentifier: String = "glassdo.settings.window",
        windowLevel: NSWindow.Level = .floating,
        onResolve: @escaping (NSWindow) -> Void = { _ in }
    ) {
        self.targetSize = targetSize
        self.minimumSize = minimumSize
        self.windowIdentifier = windowIdentifier
        self.windowLevel = windowLevel
        self.onResolve = onResolve
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            configure(window)
            onResolve(window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            configure(window)
            onResolve(window)
        }
    }

    private func configure(_ window: NSWindow) {
        ensureWindowCanBecomeKey(window)

        if window.identifier?.rawValue != windowIdentifier {
            window.identifier = NSUserInterfaceItemIdentifier(windowIdentifier)
            window.styleMask = [.borderless, .fullSizeContentView]
            window.isMovableByWindowBackground = false
            window.backgroundColor = .clear
            window.isOpaque = false
            window.hasShadow = true
            window.level = windowLevel
            window.collectionBehavior = [.fullScreenAuxiliary]
            window.standardWindowButton(.closeButton)?.isHidden = true
            window.standardWindowButton(.miniaturizeButton)?.isHidden = true
            window.standardWindowButton(.zoomButton)?.isHidden = true
        }

        window.minSize = NSSize(width: minimumSize.width, height: minimumSize.height)
        let desiredSize = NSSize(width: targetSize.width, height: targetSize.height)
        if window.frame.size != desiredSize {
            window.setContentSize(desiredSize)
        }
    }

    private func ensureWindowCanBecomeKey(_ window: NSWindow) {
        guard let windowClass = object_getClass(window) else { return }

        let classID = ObjectIdentifier(windowClass)
        guard !Self.patchedWindowClasses.contains(classID) else { return }

        let canBecomeKey: @convention(block) (AnyObject) -> Bool = { _ in true }
        let canBecomeMain: @convention(block) (AnyObject) -> Bool = { _ in true }

        class_addMethod(
            windowClass,
            #selector(getter: NSWindow.canBecomeKey),
            imp_implementationWithBlock(canBecomeKey),
            "B@:"
        )
        class_addMethod(
            windowClass,
            #selector(getter: NSWindow.canBecomeMain),
            imp_implementationWithBlock(canBecomeMain),
            "B@:"
        )

        Self.patchedWindowClasses.insert(classID)
    }
}
