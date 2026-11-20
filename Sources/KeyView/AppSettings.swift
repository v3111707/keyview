import Carbon.HIToolbox
import Foundation

/// A keyboard shortcut: a physical key (`kVK_*`) plus Carbon modifiers (`cmdKey`, `optionKey`, ...).
struct Shortcut: Equatable {
    var keyCode: UInt32
    var modifiers: UInt32

    /// ⌥⌘K
    static let standard = Shortcut(keyCode: UInt32(kVK_ANSI_K), modifiers: UInt32(cmdKey | optionKey))
}

/// Settings the user can change. Saved in UserDefaults.
final class AppSettings: ObservableObject {
    private enum Keys {
        static let theme = "theme"
        static let rightIndexShade = "rightIndexShade"
        static let opacity = "opacity"
        static let hotKeyCode = "hotKeyCode"
        static let hotKeyModifiers = "hotKeyModifiers"
    }

    private let defaults: UserDefaults

    @Published var theme: Theme {
        didSet { defaults.set(theme.rawValue, forKey: Keys.theme) }
    }

    /// Left and right index fingers get different shades.
    @Published var rightIndexShade: Bool {
        didSet { defaults.set(rightIndexShade, forKey: Keys.rightIndexShade) }
    }

    /// Opacity of the keyboard window, 0.2...1.
    @Published var opacity: Double {
        didSet { defaults.set(opacity, forKey: Keys.opacity) }
    }

    /// Shows or hides the keyboard window from any app.
    @Published var hotKey: Shortcut {
        didSet {
            defaults.set(Int(hotKey.keyCode), forKey: Keys.hotKeyCode)
            defaults.set(Int(hotKey.modifiers), forKey: Keys.hotKeyModifiers)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        theme = defaults.string(forKey: Keys.theme).flatMap(Theme.init(rawValue:)) ?? .classic
        rightIndexShade = defaults.bool(forKey: Keys.rightIndexShade)
        let savedOpacity = defaults.object(forKey: Keys.opacity) as? Double ?? 1
        opacity = min(max(savedOpacity, 0.2), 1)
        if let code = (defaults.object(forKey: Keys.hotKeyCode) as? Int).flatMap(UInt32.init(exactly:)),
           let modifiers = (defaults.object(forKey: Keys.hotKeyModifiers) as? Int).flatMap(UInt32.init(exactly:)) {
            hotKey = Shortcut(keyCode: code, modifiers: modifiers)
        } else {
            hotKey = .standard
        }
    }
}
