import Carbon.HIToolbox
import Foundation

/// Reads key symbols from the current macOS input source and follows its changes.
final class LayoutReader: NSObject {
    private var onChange: (([UInt16: KeyLabels]) -> Void)?

    /// Calls `onChange` now and after every input source switch.
    func start(onChange: @escaping ([UInt16: KeyLabels]) -> Void) {
        self.onChange = onChange
        onChange(Self.currentLabels())
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
            self?.onChange?(Self.currentLabels())
        }
    }

    /// Symbols of all layout keys for the current input source. Input methods without
    /// their own key layout (for example Japanese) fall back to the ASCII layout they use.
    static func currentLabels() -> [UInt16: KeyLabels] {
        labels(for: TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue())
            ?? labels(for: TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue())
            ?? [:]
    }

    /// Symbols of all layout keys for an input source. `nil` if it has no key layout.
    static func labels(for source: TISInputSource?) -> [UInt16: KeyLabels]? {
        guard let source, let raw = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return nil
        }
        let data = Unmanaged<CFData>.fromOpaque(raw).takeUnretainedValue() as Data
        return data.withUnsafeBytes { bytes -> [UInt16: KeyLabels]? in
            guard let layout = bytes.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else { return nil }
            var labels: [UInt16: KeyLabels] = [:]
            for key in Keyboard.keys where key.fixedLabel == nil {
                guard let code = key.code else { continue }
                labels[code] = KeyLabels(
                    base: translate(code, modifiers: 0, layout),
                    shift: translate(code, modifiers: shiftKey, layout),
                    caps: translate(code, modifiers: alphaLock, layout),
                    capsShift: translate(code, modifiers: shiftKey | alphaLock, layout)
                )
            }
            return labels
        }
    }

    private static func translate(_ code: UInt16, modifiers: Int, _ layout: UnsafePointer<UCKeyboardLayout>) -> String {
        let maxLength = 4
        var chars = [UniChar](repeating: 0, count: maxLength)
        var length = 0
        var deadKeyState: UInt32 = 0
        let status = UCKeyTranslate(
            layout,
            code,
            UInt16(kUCKeyActionDisplay),
            UInt32((modifiers >> 8) & 0xFF),
            UInt32(LMGetKbdType()),
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
