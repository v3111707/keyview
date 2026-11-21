import AppKit
import Carbon.HIToolbox

/// A keyboard input source the user can switch to, like ABC or Russian.
struct InputSource {
    let id: String
    let name: String
    /// Two letters for the menu bar, like the macOS indicator: РУ, EN.
    let shortName: String
    private let source: TISInputSource

    init(_ source: TISInputSource) {
        self.source = source
        id = Self.string(source, kTISPropertyInputSourceID) ?? ""
        name = Self.string(source, kTISPropertyLocalizedName) ?? id
        shortName = Self.shortName(language: Self.languages(source).first, name: name)
    }

    /// The input source the user types with now.
    static func current() -> InputSource? {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else { return nil }
        return InputSource(source)
    }

    /// Input sources turned on in System Settings, in their order.
    static func enabled() -> [InputSource] {
        let filter = [
            kTISPropertyInputSourceCategory as String: kTISCategoryKeyboardInputSource as String,
            kTISPropertyInputSourceIsSelectCapable as String: true,
        ] as CFDictionary
        let list = TISCreateInputSourceList(filter, false)?.takeRetainedValue() as? [TISInputSource] ?? []
        return list.map(InputSource.init)
    }

    /// Makes this the current input source.
    func select() {
        TISSelectInputSource(source)
    }

    /// First two letters of the language name in that language: русский → РУ, English → EN.
    /// Without a language, the first two letters of the input source name.
    static func shortName(language: String?, name: String) -> String {
        if let language, !language.isEmpty {
            let locale = Locale(identifier: language)
            let code = Locale.Language(identifier: language).languageCode?.identifier ?? language
            if let native = locale.localizedString(forLanguageCode: code), !native.isEmpty {
                return String(native.prefix(2)).uppercased(with: locale)
            }
        }
        return String(name.prefix(2)).uppercased()
    }

    /// Menu bar picture: the short name in a rounded frame, like the macOS indicator.
    /// A template image, so macOS colors it for light and dark menu bars.
    static func badge(_ text: String, height: CGFloat = 16) -> NSImage {
        let font = NSFont.systemFont(ofSize: height * 0.69, weight: .semibold)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.black]
        let textSize = (text as NSString).size(withAttributes: attributes)
        let size = NSSize(width: max(ceil(textSize.width) + height * 0.6, height * 1.4), height: height)
        let image = NSImage(size: size, flipped: false) { rect in
            let frame = rect.insetBy(dx: 0.75, dy: 0.75)
            let path = NSBezierPath(roundedRect: frame, xRadius: height * 0.25, yRadius: height * 0.25)
            path.lineWidth = 1.5
            NSColor.black.setStroke()
            path.stroke()
            let origin = NSPoint(x: rect.midX - textSize.width / 2, y: rect.midY - textSize.height / 2)
            (text as NSString).draw(at: origin, withAttributes: attributes)
            return true
        }
        image.isTemplate = true
        return image
    }

    private static func string(_ source: TISInputSource, _ key: CFString) -> String? {
        guard let raw = TISGetInputSourceProperty(source, key) else { return nil }
        return Unmanaged<CFString>.fromOpaque(raw).takeUnretainedValue() as String
    }

    private static func languages(_ source: TISInputSource) -> [String] {
        guard let raw = TISGetInputSourceProperty(source, kTISPropertyInputSourceLanguages) else { return [] }
        return Unmanaged<CFArray>.fromOpaque(raw).takeUnretainedValue() as? [String] ?? []
    }
}
