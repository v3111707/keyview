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
    /// See-through keys on a gradient, thin edge in the finger color.
    case glass
    /// Dark keys with glowing outlines and text in the finger color.
    case neon
    /// Keys filled with a gradient of the finger color.
    case gradient
    /// Plain keys with a dot in the finger color.
    case dot

    var id: Self { self }

    var title: String { rawValue.capitalized }

    /// Corner radius of a key, in key units.
    var cornerRadius: CGFloat {
        switch self {
        case .classic: return 0.12
        case .vivid: return 0.18
        case .minimal: return 0.1
        case .outline: return 0.16
        case .glass: return 0.2
        case .neon: return 0.14
        case .gradient: return 0.2
        case .dot: return 0.16
        }
    }

    var fontDesign: Font.Design {
        switch self {
        case .outline, .neon: return .monospaced
        case .glass, .gradient: return .rounded
        default: return .default
        }
    }

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
        case .glass:
            return dark ? Palette(dark: true, background: 0x1B2040, background2: 0x3A1D4D, key: 0x2A2C48, text: 0xF2F2F7)
                        : Palette(dark: false, background: 0xDCE6FF, background2: 0xF4E2FF, key: 0xFFFFFF, text: 0x1D1D1F)
        case .neon:
            // Neon only works on a dark background, so it stays dark in light mode too.
            return Palette(dark: true, background: 0x07070B, key: 0x101018, text: 0xF2F2F7)
        case .gradient:
            return dark ? Palette(dark: true, background: 0x111114, key: 0x323237, text: 0xF2F2F7)
                        : Palette(dark: false, background: 0xF0F0F3, key: 0xCFCFD6, text: 0x1D1D1F)
        case .dot:
            return dark ? Palette(dark: true, background: 0x1A1A1C, key: 0x2A2A2D, text: 0xF2F2F7)
                        : Palette(dark: false, background: 0xE9E9EC, key: 0xFFFFFF, text: 0x1D1D1F)
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
        case .glass:
            if pressed {
                return KeyLook(fill: palette.strong(finger).opacity(0.85), stroke: palette.strong(finger),
                               strokeWidth: 0.025, ink: .white)
            }
            let edge = plain ? (palette.dark ? Color.white.opacity(0.18) : Color.black.opacity(0.1))
                             : palette.accent(finger).opacity(0.75)
            return KeyLook(fill: palette.dark ? Color.white.opacity(0.08) : Color.white.opacity(0.55),
                           stroke: edge, strokeWidth: 0.025, ink: palette.text)
        case .neon:
            let line = plain ? Color.white.opacity(0.3) : palette.accent(finger)
            if pressed {
                let light = plain ? Color.white : line
                return KeyLook(fill: light, stroke: light, glow: light, ink: .black, bold: true)
            }
            return KeyLook(fill: palette.key, stroke: line, glow: plain ? nil : line,
                           ink: plain ? Color.white.opacity(0.8) : line)
        case .gradient:
            if pressed {
                return KeyLook(fill: palette.dark ? .white : palette.text, ink: palette.dark ? .black : .white, bold: true)
            }
            return KeyLook(gradient: palette.gradient(finger), ink: plain ? palette.text : .white, bold: !plain)
        case .dot:
            if pressed {
                return KeyLook(fill: palette.strong(finger), ink: .white)
            }
            return KeyLook(fill: palette.key, dot: plain ? nil : palette.accent(finger), ink: palette.text)
        }
    }
}

/// How to draw one key. `nil` parts are not drawn.
struct KeyLook: Equatable {
    var fill: Color? = nil
    /// Top and bottom color of a gradient fill.
    var gradient: [Color]? = nil
    var stroke: Color? = nil
    /// Width of the stroke, in key units.
    var strokeWidth: CGFloat = 0.04
    /// Glow around the key.
    var glow: Color? = nil
    /// Line in the finger color at the bottom of the key.
    var bar: Color? = nil
    /// Dot in the finger color at the top right of the key.
    var dot: Color? = nil
    var ink: Color
    var bold = false
}

/// Colors of one theme in light or dark mode.
struct Palette {
    let dark: Bool
    /// One color, or two for a gradient from the top left to the bottom right.
    let backgroundColors: [Color]
    /// Key without a finger color.
    let key: Color
    let text: Color
    private let softColors: [Finger: Color]
    private let accentColors: [Finger: Color]
    private let strongColors: [Finger: Color]
    private let gradientColors: [Finger: [Color]]

    var background: LinearGradient {
        LinearGradient(colors: backgroundColors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Pastel finger color. The inner index column is paler.
    func soft(_ finger: Finger) -> Color { softColors[finger] ?? key }
    /// Bright finger color. The inner index column is paler.
    func accent(_ finger: Finger) -> Color { accentColors[finger] ?? key }
    /// Fill of a pressed key.
    func strong(_ finger: Finger) -> Color { strongColors[finger] ?? key }
    /// Top and bottom color of a gradient key.
    func gradient(_ finger: Finger) -> [Color] { gradientColors[finger] ?? [key, key] }

    fileprivate init(dark: Bool, background: UInt32, background2: UInt32? = nil, key: UInt32, text: UInt32) {
        self.dark = dark
        let backgroundRGB = RGB(background)
        let keyRGB = RGB(key)
        backgroundColors = [backgroundRGB.color] + (background2.map { [RGB($0).color] } ?? [])
        self.key = keyRGB.color
        self.text = RGB(text).color

        // The right index finger has an amber shade of the same orange family.
        let bright: [Finger: RGB] = [
            .pinky: RGB(0x8B5CF6), .ring: RGB(0x3B82F6), .middle: RGB(0x22A35A),
            .index: RGB(0xF08C1A), .indexRight: RGB(0xDDB21C), .thumb: RGB(0x14B8A6),
        ]
        let pastel: [Finger: RGB] = dark
            ? [.pinky: RGB(0x52407A), .ring: RGB(0x2E4C75), .middle: RGB(0x2F5C3A),
               .index: RGB(0x7A5024), .indexRight: RGB(0x6E5C1E), .thumb: RGB(0x245E5A)]
            : [.pinky: RGB(0xDCCBF7), .ring: RGB(0xC9DDF8), .middle: RGB(0xCDEDCB),
               .index: RGB(0xFAD7B0), .indexRight: RGB(0xF7EAB0), .thumb: RGB(0xC3ECE8)]

        var soft = pastel
        var accent = bright
        var strong = bright
        // The inner index column: same color, paler. A pressed key shows the full color.
        for (inner, outer) in [(Finger.indexInner, Finger.index), (.indexInnerRight, .indexRight)] {
            soft[inner] = pastel[outer]?.mixed(with: keyRGB, 0.5)
            accent[inner] = bright[outer]?.mixed(with: backgroundRGB, 0.45)
            strong[inner] = bright[outer]
        }
        soft[.neutral] = keyRGB
        strong[.neutral] = RGB(0x7C7C85)

        softColors = soft.mapValues(\.color)
        accentColors = accent.mapValues(\.color)
        strongColors = strong.mapValues(\.color)

        let white = RGB(0xFFFFFF)
        let black = RGB(0x000000)
        var gradient = accent.mapValues { [$0.mixed(with: white, 0.2).color, $0.mixed(with: black, 0.15).color] }
        gradient[.neutral] = [keyRGB.mixed(with: white, 0.08).color, keyRGB.mixed(with: black, 0.1).color]
        gradientColors = gradient
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
