import SwiftUI

/// How the keys look. Picked in Settings → Themes.
enum Theme: String, CaseIterable, Identifiable {
    /// Pastel keys in the finger color.
    case classic
    /// Bright keys in the finger color, white text.
    case vivid
    /// Plain keys with a bar in the finger color.
    case minimal
    /// Outlines and text in the finger color.
    case outline

    var id: Self { self }

    var title: String { rawValue.capitalized }

    /// Corner radius of a key, in key units.
    var cornerRadius: CGFloat {
        switch self {
        case .classic: return 0.12
        case .vivid: return 0.18
        case .minimal: return 0.1
        case .outline: return 0.16
        }
    }

    var fontDesign: Font.Design { self == .outline ? .monospaced : .default }

    func palette(dark: Bool) -> Palette {
        switch self {
        case .classic:
            return dark ? Palette(dark: true, background: 0x1C1C1E, key: 0x3A3A3C, text: 0xF2F2F7)
                        : Palette(dark: false, background: 0xD1D3D9, key: 0xF5F5F7, text: 0x1D1D1F)
        case .vivid:
            return dark ? Palette(dark: true, background: 0x101014, key: 0x2C2C30, text: 0xF2F2F7)
                        : Palette(dark: false, background: 0xE4E6EB, key: 0x9A9AA3, text: 0x1D1D1F)
        case .minimal:
            return dark ? Palette(dark: true, background: 0x1C1C1E, key: 0x2E2E31, text: 0xF2F2F7)
                        : Palette(dark: false, background: 0xECECEF, key: 0xFFFFFF, text: 0x1D1D1F)
        case .outline:
            return dark ? Palette(dark: true, background: 0x0E0E10, key: 0x0E0E10, text: 0xF2F2F7)
                        : Palette(dark: false, background: 0xFAFAFA, key: 0xFAFAFA, text: 0x1D1D1F)
        }
    }

    /// Colors of one key.
    func look(_ finger: Finger, pressed: Bool, in palette: Palette) -> KeyLook {
        let plain = finger == .neutral
        switch self {
        case .classic:
            return pressed ? KeyLook(fill: palette.strong(finger), ink: .white)
                           : KeyLook(fill: palette.soft(finger), ink: palette.text)
        case .vivid:
            if pressed {
                return KeyLook(fill: palette.dark ? .white : palette.text, ink: palette.dark ? .black : .white, bold: true)
            }
            return KeyLook(fill: plain ? palette.key : palette.accent(finger), ink: .white, bold: true)
        case .minimal:
            if pressed {
                return KeyLook(fill: palette.strong(finger), ink: .white)
            }
            return KeyLook(fill: palette.key, bar: plain ? nil : palette.accent(finger), ink: palette.text)
        case .outline:
            let line = plain ? palette.text.opacity(0.35) : palette.accent(finger)
            if pressed {
                return KeyLook(fill: palette.strong(finger), stroke: line, ink: .white)
            }
            return KeyLook(stroke: line, ink: plain ? palette.text : line)
        }
    }
}

/// How to draw one key. `nil` parts are not drawn.
struct KeyLook {
    var fill: Color? = nil
    var stroke: Color? = nil
    /// Line in the finger color at the bottom of the key.
    var bar: Color? = nil
    var ink: Color
    var bold = false
}

/// Colors of one theme in light or dark mode.
struct Palette {
    let dark: Bool
    let background: Color
    /// Key without a finger color.
    let key: Color
    let text: Color
    private let softColors: [Finger: Color]
    private let accentColors: [Finger: Color]
    private let strongColors: [Finger: Color]

    /// Pastel finger color. The inner index column is paler.
    func soft(_ finger: Finger) -> Color { softColors[finger] ?? key }
    /// Bright finger color. The inner index column is paler.
    func accent(_ finger: Finger) -> Color { accentColors[finger] ?? key }
    /// Fill of a pressed key.
    func strong(_ finger: Finger) -> Color { strongColors[finger] ?? key }

    fileprivate init(dark: Bool, background: UInt32, key: UInt32, text: UInt32) {
        self.dark = dark
        let backgroundRGB = RGB(background)
        let keyRGB = RGB(key)
        self.background = backgroundRGB.color
        self.key = keyRGB.color
        self.text = RGB(text).color

        let bright: [Finger: RGB] = [
            .pinky: RGB(0x8B5CF6), .ring: RGB(0x3B82F6), .middle: RGB(0x22A35A),
            .index: RGB(0xF08C1A), .thumb: RGB(0x14B8A6),
        ]
        let pastel: [Finger: RGB] = dark
            ? [.pinky: RGB(0x52407A), .ring: RGB(0x2E4C75), .middle: RGB(0x2F5C3A),
               .index: RGB(0x7A5024), .thumb: RGB(0x245E5A)]
            : [.pinky: RGB(0xDCCBF7), .ring: RGB(0xC9DDF8), .middle: RGB(0xCDEDCB),
               .index: RGB(0xFAD7B0), .thumb: RGB(0xC3ECE8)]

        var soft = pastel
        soft[.indexInner] = pastel[.index]?.mixed(with: keyRGB, 0.5)
        soft[.neutral] = keyRGB
        var accent = bright
        accent[.indexInner] = RGB(0xF08C1A).mixed(with: backgroundRGB, 0.45)
        var strong = bright
        strong[.indexInner] = RGB(0xF08C1A)
        strong[.neutral] = RGB(0x7C7C85)

        softColors = soft.mapValues(\.color)
        accentColors = accent.mapValues(\.color)
        strongColors = strong.mapValues(\.color)
    }
}

private struct RGB {
    var r, g, b: Double

    init(_ hex: UInt32) {
        r = Double((hex >> 16) & 0xFF) / 255
        g = Double((hex >> 8) & 0xFF) / 255
        b = Double(hex & 0xFF) / 255
    }

    init(r: Double, g: Double, b: Double) {
        self.r = r
        self.g = g
        self.b = b
    }

    func mixed(with other: RGB, _ amount: Double) -> RGB {
        RGB(r: r + (other.r - r) * amount, g: g + (other.g - g) * amount, b: b + (other.b - b) * amount)
    }

    var color: Color { Color(red: r, green: g, blue: b) }
}
