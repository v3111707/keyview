import Carbon.HIToolbox
import Foundation

/// Reads key symbols from the current macOS input source and follows its changes.
final class LayoutReader: NSObject {
    private var onChange: (() -> Void)?

    /// Calls `onChange` after every input source switch.
    func start(onChange: @escaping () -> Void) {
        self.onChange = onChange
        // The app is almost never active, so ask for immediate delivery.
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(inputSourceChanged),
            name: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil,
            suspensionBehavior: .deliverImmediately
        )
    }

    @objc private func inputSourceChanged() {
        DispatchQueue.main.async { [weak self] in
            self?.onChange?()
        }
    }

    /// Symbols of all layout keys for the current input source. Input methods without
    /// their own key layout (for example Japanese) fall back to the ASCII layout they use.
    /// `keyboardType` is a macOS keyboard type: ANSI and ISO keyboards map some keys differently.
    static func currentLabels(keyboardType: UInt32) -> [UInt16: KeyLabels] {
        labels(for: TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(), keyboardType: keyboardType)
            ?? labels(for: TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
                      keyboardType: keyboardType)
            ?? [:]
    }

    /// Symbols of all layout keys for an input source. `nil` if it has no key layout.
    static func labels(for source: TISInputSource?, keyboardType: UInt32) -> [UInt16: KeyLabels]? {
        withLayout(of: source) { layout in
            var labels: [UInt16: KeyLabels] = [:]
            for key in Keyboard.ansi + Keyboard.iso where key.fixedLabel == nil {
                guard let code = key.code else { continue }
                func symbol(_ modifiers: Int) -> String {
                    translate(code, modifiers: modifiers, keyboardType: keyboardType, layout)
                }
                labels[code] = KeyLabels(
                    base: symbol(0),
                    shift: symbol(shiftKey),
                    caps: symbol(alphaLock),
                    capsShift: symbol(shiftKey | alphaLock)
                )
            }
            return labels
        }
    }

    /// Name of a key in a shortcut: its symbol in the ASCII layout (K, 7, /) or a sign like ↩.
    static func keyName(_ code: UInt16) -> String {
        if let name = keyNames[Int(code)] { return name }
        let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue()
        let symbol = withLayout(of: source) { layout in
            translate(code, modifiers: 0, keyboardType: UInt32(LMGetKbdType()), layout)
        } ?? ""
        return symbol.isEmpty ? "Key \(code)" : symbol.uppercased()
    }

    /// F1 to F20 in order.
    static let functionKeys = [
        kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8, kVK_F9, kVK_F10,
        kVK_F11, kVK_F12, kVK_F13, kVK_F14, kVK_F15, kVK_F16, kVK_F17, kVK_F18, kVK_F19, kVK_F20,
    ]

    /// Keys that have no symbol in a layout.
    private static let keyNames: [Int: String] = {
        var names: [Int: String] = [
            kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Delete: "⌫", kVK_ForwardDelete: "⌦",
            kVK_Escape: "⎋", kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
            kVK_Home: "↖", kVK_End: "↘", kVK_PageUp: "⇞", kVK_PageDown: "⇟", kVK_ANSI_KeypadEnter: "⌤",
        ]
        for (index, code) in functionKeys.enumerated() {
            names[code] = "F\(index + 1)"
        }
        return names
    }()

    /// Runs `body` with the key layout of `source`. `nil` if the source has none.
    private static func withLayout<Result>(
        of source: TISInputSource?,
        _ body: (UnsafePointer<UCKeyboardLayout>) -> Result
    ) -> Result? {
        guard let source, let raw = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return nil
        }
        let data = Unmanaged<CFData>.fromOpaque(raw).takeUnretainedValue() as Data
        return data.withUnsafeBytes { bytes in
            bytes.baseAddress.map { body($0.assumingMemoryBound(to: UCKeyboardLayout.self)) }
        }
    }

    private static func translate(_ code: UInt16, modifiers: Int, keyboardType: UInt32,
                                  _ layout: UnsafePointer<UCKeyboardLayout>) -> String {
        let maxLength = 4
        var chars = [UniChar](repeating: 0, count: maxLength)
        var length = 0
        var deadKeyState: UInt32 = 0
        let status = UCKeyTranslate(
            layout,
            code,
            UInt16(kUCKeyActionDisplay),
            UInt32((modifiers >> 8) & 0xFF),
            keyboardType,
            OptionBits(kUCKeyTranslateNoDeadKeysMask), // dead keys show their own symbol
            &deadKeyState,
            maxLength,
            &length,
            &chars
        )
        guard status == noErr, length > 0 else { return "" }
        let text = String(utf16CodeUnits: chars, count: length)
        // Control characters and spaces have nothing to show.
        let visible = text.unicodeScalars.contains {
            !$0.properties.isWhitespace && $0.properties.generalCategory != .control
        }
        return visible ? text : ""
    }
}
