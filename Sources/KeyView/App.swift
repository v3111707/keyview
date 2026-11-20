import AppKit
import Carbon.HIToolbox

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let opacityKey = "opacity"

    private let state = KeyboardState()
    private let layoutReader = LayoutReader()
    private lazy var keyMonitor = KeyMonitor(state: state)
    private var window: KeyboardWindow!
    private var statusItem: NSStatusItem!
    private var toggleItem: NSMenuItem!
    private var hotKey: HotKey?

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory) // menu bar only, no Dock icon
        withExtendedLifetime(delegate) { app.run() }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        window = KeyboardWindow.make(state: state)
        window.alphaValue = Self.savedOpacity()
        setUpMenu()
        layoutReader.start { [state] labels in state.labels = labels }
        keyMonitor.start()
        hotKey = HotKey(keyCode: kVK_ANSI_K, modifiers: cmdKey | optionKey) { [weak self] in
            self?.toggleWindow()
        }
        showWindow()
    }

    // MARK: Window

    @objc private func toggleWindow() {
        if window.isVisible {
            hideWindow()
        } else {
            showWindow()
        }
    }

    private func showWindow() {
        window.orderFrontRegardless()
        keyMonitor.setEnabled(true)
        toggleItem.title = "Hide Window"
    }

    private func hideWindow() {
        window.orderOut(nil)
        keyMonitor.setEnabled(false)
        toggleItem.title = "Show Window"
    }

    // MARK: Menu

    private func setUpMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let icon = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "KeyView")
        icon?.isTemplate = true
        statusItem.button?.image = icon

        let menu = NSMenu()
        toggleItem = NSMenuItem(title: "Hide Window", action: #selector(toggleWindow), keyEquivalent: "k")
        toggleItem.keyEquivalentModifierMask = [.command, .option]
        toggleItem.target = self
        menu.addItem(toggleItem)

        menu.addItem(.separator())
        menu.addItem(.sectionHeader(title: "Opacity"))
        let sliderItem = NSMenuItem()
        sliderItem.view = makeOpacitySlider()
        menu.addItem(sliderItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit KeyView", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    private func makeOpacitySlider() -> NSView {
        let slider = NSSlider(value: Double(window.alphaValue), minValue: 0.2, maxValue: 1,
                              target: self, action: #selector(opacityChanged(_:)))
        slider.isContinuous = true
        slider.frame = NSRect(x: 18, y: 4, width: 184, height: 22)
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 220, height: 30))
        container.addSubview(slider)
        return container
    }

    @objc private func opacityChanged(_ slider: NSSlider) {
        window.alphaValue = CGFloat(slider.doubleValue)
        UserDefaults.standard.set(slider.doubleValue, forKey: Self.opacityKey)
    }

    private static func savedOpacity() -> CGFloat {
        let value = UserDefaults.standard.object(forKey: opacityKey) as? Double ?? 1
        return CGFloat(min(max(value, 0.2), 1))
    }
}
