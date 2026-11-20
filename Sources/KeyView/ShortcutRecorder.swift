import AppKit
import Carbon.HIToolbox

extension Shortcut {
    /// Shortcut from a key press. `nil` without ⌘ or ⌃: macOS does not allow global
    /// shortcuts with only ⌥ or ⇧, and a plain key would get in the way of typing.
    init?(keyCode: UInt16, flags: NSEvent.ModifierFlags) {
        guard flags.contains(.command) || flags.contains(.control) else { return nil }
        var modifiers = 0
        if flags.contains(.control) { modifiers |= controlKey }
        if flags.contains(.option) { modifiers |= optionKey }
        if flags.contains(.shift) { modifiers |= shiftKey }
        if flags.contains(.command) { modifiers |= cmdKey }
        self.init(keyCode: UInt32(keyCode), modifiers: UInt32(modifiers))
    }

    var modifierFlags: NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if modifiers & UInt32(controlKey) != 0 { flags.insert(.control) }
        if modifiers & UInt32(optionKey) != 0 { flags.insert(.option) }
        if modifiers & UInt32(shiftKey) != 0 { flags.insert(.shift) }
        if modifiers & UInt32(cmdKey) != 0 { flags.insert(.command) }
        return flags
    }

    /// For example "⌥⌘K". Modifiers go in the macOS order: ⌃⌥⇧⌘.
    var displayString: String {
        let flags = modifierFlags
        var text = ""
        if flags.contains(.control) { text += "⌃" }
        if flags.contains(.option) { text += "⌥" }
        if flags.contains(.shift) { text += "⇧" }
        if flags.contains(.command) { text += "⌘" }
        return text + LayoutReader.keyName(UInt16(truncatingIfNeeded: keyCode))
    }

    /// Key equivalent to show in a menu item, or "" if the key has no menu form.
    var menuKeyEquivalent: String {
        let code = Int(keyCode)
        if let index = LayoutReader.functionKeys.firstIndex(of: code) {
            return Self.character(NSF1FunctionKey + index)
        }
        switch code {
        case kVK_LeftArrow: return Self.character(NSLeftArrowFunctionKey)
        case kVK_RightArrow: return Self.character(NSRightArrowFunctionKey)
        case kVK_UpArrow: return Self.character(NSUpArrowFunctionKey)
        case kVK_DownArrow: return Self.character(NSDownArrowFunctionKey)
        case kVK_Space: return " "
        case kVK_Return: return "\r"
        case kVK_Tab: return "\t"
        case kVK_Delete: return "\u{8}"
        case kVK_Escape: return "\u{1b}"
        default:
            let name = LayoutReader.keyName(UInt16(truncatingIfNeeded: keyCode))
            return name.count == 1 ? name.lowercased() : ""
        }
    }

    private static func character(_ value: Int) -> String {
        UnicodeScalar(UInt32(value)).map { String(Character($0)) } ?? ""
    }
}

/// Records a new hotkey in Settings → General.
@MainActor
final class ShortcutRecorder: ObservableObject {
    static let needsCommandOrControl = "Use ⌘ or ⌃ in the shortcut."
    static let refused = "macOS did not accept this shortcut. It may be taken by the system or another app."

    @Published private(set) var isRecording = false
    /// Problem to show under the shortcut.
    @Published var message: String?

    /// Turns the current hotkey off while recording, so pressing it again does not fire.
    var pause: () -> Void = {}
    /// Turns the current hotkey back on after a cancelled recording.
    var resume: () -> Void = {}
    /// Tries to use a new shortcut. Returns `false` if macOS refused it; the old one then stays.
    var apply: (Shortcut) -> Bool = { _ in true }

    private var monitor: Any?

    func start() {
        guard !isRecording else { return }
        message = nil
        isRecording = true
        pause()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.record(event)
            return nil // the key press only sets the shortcut
        }
    }

    func cancel() {
        guard isRecording else { return }
        stop()
        resume()
    }

    /// Uses `shortcut` without recording, for example the standard one.
    func use(_ shortcut: Shortcut) {
        message = apply(shortcut) ? nil : Self.refused
    }

    /// Handles one key press while recording.
    func record(_ event: NSEvent) {
        guard isRecording else { return }
        let flags = event.modifierFlags.intersection([.command, .control, .option, .shift])
        if Int(event.keyCode) == kVK_Escape && flags.isEmpty {
            cancel()
            return
        }
        guard let shortcut = Shortcut(keyCode: event.keyCode, flags: flags) else {
            message = Self.needsCommandOrControl
            return
        }
        stop()
        message = apply(shortcut) ? nil : Self.refused
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        isRecording = false
    }
}
