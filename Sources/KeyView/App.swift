import AppKit
import Carbon.HIToolbox

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let state = KeyboardState()
    private let settings = AppSettings()
    private let recorder = ShortcutRecorder()
    private let layoutReader = LayoutReader()
    private lazy var keyMonitor = KeyMonitor(state: state)
    private lazy var hotKey = HotKey { [weak self] in self?.toggleWindow() }
    private lazy var settingsWindow = SettingsWindowController(settings: settings, recorder: recorder, state: state)
    private var window: KeyboardWindow!
    private var statusItem: NSStatusItem!
    private var toggleItem: NSMenuItem!

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory) // menu bar only, no Dock icon
        withExtendedLifetime(delegate) { app.run() }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        window = KeyboardWindow.make(state: state, settings: settings)
        window.alphaValue = settings.opacity
        setUpMenu()
        state.keyboardType = UInt32(LMGetKbdType())
        refreshLabels()
        layoutReader.start { [weak self] in self?.refreshLabels() }
        keyMonitor.onKeyboardTypeChange = { [weak self] in self?.refreshLabels() }
        keyMonitor.start()
        setUpHotKey()
        showWindow()
    }

    /// Reads the symbols of the current layout for the current keyboard type.
    private func refreshLabels() {
        state.labels = LayoutReader.currentLabels(keyboardType: state.keyboardType)
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
        // Key presses tell the keyboard type. Until one arrives, only macOS can tell it.
        if !keyMonitor.seesKeyPresses {
            state.keyboardType = UInt32(LMGetKbdType())
        }
        refreshLabels()
        window.orderFrontRegardless()
        keyMonitor.setEnabled(true)
        toggleItem.title = "Hide Window"
    }

    private func hideWindow() {
        window.orderOut(nil)
        keyMonitor.setEnabled(false)
        toggleItem.title = "Show Window"
    }

    // MARK: Hotkey

    private func setUpHotKey() {
        recorder.pause = { [weak self] in self?.hotKey.register(nil) }
        recorder.resume = { [weak self] in self?.restoreHotKey() }
        recorder.apply = { [weak self] shortcut in self?.applyHotKey(shortcut) ?? false }
        if !restoreHotKey() {
            recorder.message = ShortcutRecorder.refused // the saved shortcut is taken now
        }
    }

    /// Turns on the saved hotkey. Returns `false` if macOS refused it.
    @discardableResult
    private func restoreHotKey() -> Bool {
        let active = hotKey.register(settings.hotKey)
        updateMenuShortcut(active: active)
        return active
    }

    /// Switches to a new hotkey. If macOS refuses it, the old one stays.
    private func applyHotKey(_ shortcut: Shortcut) -> Bool {
        guard hotKey.register(shortcut) else {
            restoreHotKey()
            return false
        }
        settings.hotKey = shortcut
        updateMenuShortcut(active: true)
        return true
    }

    private func updateMenuShortcut(active: Bool) {
        toggleItem.keyEquivalent = active ? settings.hotKey.menuKeyEquivalent : ""
        toggleItem.keyEquivalentModifierMask = settings.hotKey.modifierFlags
    }

    // MARK: Menu

    private func setUpMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let icon = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "KeyView")
        icon?.isTemplate = true
        statusItem.button?.image = icon

        let menu = NSMenu()
        toggleItem = NSMenuItem(title: "Hide Window", action: #selector(toggleWindow), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)

        menu.addItem(.separator())
        menu.addItem(.sectionHeader(title: "Opacity"))
        let sliderItem = NSMenuItem()
        sliderItem.view = makeOpacitySlider()
        menu.addItem(sliderItem)

        menu.addItem(.separator())
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(NSMenuItem(title: "Quit KeyView", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    @objc private func openSettings() {
        settingsWindow.show()
    }

    private func makeOpacitySlider() -> NSView {
        let slider = NSSlider(value: settings.opacity, minValue: 0.2, maxValue: 1,
                              target: self, action: #selector(opacityChanged(_:)))
        slider.isContinuous = true
        slider.frame = NSRect(x: 18, y: 4, width: 184, height: 22)
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 220, height: 30))
        container.addSubview(slider)
        return container
    }

    @objc private func opacityChanged(_ slider: NSSlider) {
        settings.opacity = slider.doubleValue
        window.alphaValue = settings.opacity
    }
}
