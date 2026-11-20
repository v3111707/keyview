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
        guard let source, let raw = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return nil
        }
        let data = Unmanaged<CFData>.fromOpaque(raw).takeUnretainedValue() as Data
        return data.withUnsafeBytes { bytes -> [UInt16: KeyLabels]? in
            guard let layout = bytes.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else { return nil }
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
