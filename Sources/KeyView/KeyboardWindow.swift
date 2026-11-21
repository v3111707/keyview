import AppKit
import SwiftUI

/// Floating panel with the keyboard: on top of other windows, on all Spaces,
/// never takes keyboard focus, keeps the keyboard proportions when resized.
final class KeyboardWindow: NSPanel {
    private static let frameName = "KeyViewWindow"

    static func make(state: KeyboardState, settings: AppSettings) -> KeyboardWindow {
        let aspect = KeyboardView.aspect
        let width: CGFloat = 760
        let window = KeyboardWindow(
            contentRect: NSRect(x: 0, y: 0, width: width, height: width * aspect.height / aspect.width),
            styleMask: [.titled, .resizable, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            window.standardWindowButton(button)?.isHidden = true
        }
        // Only drawn pixels show, so the background behind the keys can be made transparent.
        window.isOpaque = false
        window.backgroundColor = .clear
        // Without this macOS lets clicks through transparent places. Clicks must stay in the window,
        // and a drag between the keys must move it.
        window.ignoresMouseEvents = false
        window.isFloatingPanel = true
        window.level = .floating
        window.hidesOnDeactivate = false
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.contentAspectRatio = aspect
        window.contentMinSize = NSSize(width: 300, height: 300 * aspect.height / aspect.width)

        let hosting = KeyboardHostingView(rootView: LiveKeyboardView(state: state, settings: settings))
        hosting.sizingOptions = [] // the window decides the size, not SwiftUI
        window.contentView = hosting

        if !window.setFrameUsingName(frameName) {
            window.placeAtBottomCenter()
        }
        _ = window.setFrameAutosaveName(frameName)
        return window
    }

    // Typing must stay in the app the user works in.
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    // A double-click on the hidden title bar must not zoom the window.
    override func zoom(_ sender: Any?) {}

    private func placeAtBottomCenter() {
        guard let area = NSScreen.main?.visibleFrame else {
            center()
            return
        }
        setFrameOrigin(NSPoint(x: area.midX - frame.width / 2, y: area.minY + 24))
    }
}

/// Hosts the SwiftUI keyboard. A drag anywhere on it moves the window.
private final class KeyboardHostingView: NSHostingView<LiveKeyboardView> {
    override func hitTest(_ point: NSPoint) -> NSView? {
        super.hitTest(point) == nil ? nil : self
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}
