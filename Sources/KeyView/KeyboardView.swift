import Carbon.HIToolbox
import SwiftUI

/// Draws the keyboard. Everything scales with the window.
struct KeyboardView: View {
    @ObservedObject var state: KeyboardState
    @Environment(\.colorScheme) private var colorScheme

    /// Space around the keys, in key units.
    static let padding: CGFloat = 0.3
    /// Size of the whole view in key units.
    static let aspect = CGSize(width: Keyboard.width + 2 * padding, height: Keyboard.height + 2 * padding)

    var body: some View {
        let palette = colorScheme == .dark ? Palette.dark : Palette.light
        Canvas { context, size in
            let unit = min(size.width / Self.aspect.width, size.height / Self.aspect.height)
            let origin = CGPoint(x: (size.width - Keyboard.width * unit) / 2,
                                 y: (size.height - Keyboard.height * unit) / 2)
            for key in Keyboard.keys(state.kind) {
                draw(key, in: context, unit: unit, origin: origin, palette: palette)
            }
        }
        .background(palette.background)
        .ignoresSafeArea()
    }

    private func draw(_ key: Key, in context: GraphicsContext, unit u: CGFloat, origin: CGPoint, palette: Palette) {
        let gap = 0.05 * u
        let radius = 0.12 * u
        let parts = key.parts.map {
            CGRect(x: origin.x + $0.minX * u, y: origin.y + $0.minY * u, width: $0.width * u, height: $0.height * u)
                .insetBy(dx: gap, dy: gap)
        }
        let rect = parts[0]
        let pressed = isPressed(key)
        let fill = GraphicsContext.Shading.color(palette.fill(key.finger, pressed: pressed))
        for part in parts {
            context.fill(Path(roundedRect: part, cornerRadius: radius, style: .continuous), with: fill)
        }
        if parts.count > 1 {
            // Join the two parts of the ISO Return into one L shape.
            let lower = parts[1]
            let joint = CGRect(x: lower.minX, y: rect.maxY - radius, width: lower.width, height: lower.minY - rect.maxY + 2 * radius)
            context.fill(Path(joint), with: fill)
        }

        let ink = pressed ? Color.white : palette.text
        if let code = key.code, Keyboard.bumpKeys.contains(code) {
            // Tactile bump, like on the real key.
            let bump = CGRect(x: rect.midX - 0.13 * u, y: rect.maxY - 0.16 * u, width: 0.26 * u, height: 0.05 * u)
            context.fill(Path(roundedRect: bump, cornerRadius: 0.025 * u), with: .color(ink.opacity(0.6)))
        }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        if let label = key.fixedLabel {
            let size = (key.rect.height < 1 ? 0.22 : 0.28) * u
            context.draw(Text(label).font(.system(size: size)).foregroundStyle(ink), at: center)
        } else if let code = key.code, let labels = state.labels[code] {
            let main = labels.main(shift: state.shift, caps: state.capsLock)
            context.draw(Text(main).font(.system(size: 0.42 * u)).foregroundStyle(ink), at: center)
            if !state.shift, let corner = labels.corner {
                context.draw(Text(corner).font(.system(size: 0.24 * u)).foregroundStyle(ink.opacity(0.45)),
                             at: CGPoint(x: rect.minX + 0.1 * u, y: rect.minY + 0.06 * u),
                             anchor: .topLeading)
            }
        }
    }

    private func isPressed(_ key: Key) -> Bool {
        guard let code = key.code else { return false }
        if Int(code) == kVK_CapsLock { return state.capsLock } // lit while Caps Lock is on
        return state.pressed.contains(code)
    }
}

/// Key colors for light and dark mode.
struct Palette {
    let background: Color
    let text: Color
    private let soft: [Finger: Color]
    private let strong: [Finger: Color]

    func fill(_ finger: Finger, pressed: Bool) -> Color {
        (pressed ? strong : soft)[finger] ?? .gray
    }

    static let light = Palette(
        background: 0xD1D3D9, text: 0x1D1D1F, neutral: 0xF5F5F7,
        pinky: 0xDCCBF7, ring: 0xC9DDF8, middle: 0xCDEDCB, index: 0xFAD7B0, thumb: 0xC3ECE8
    )
    static let dark = Palette(
        background: 0x1C1C1E, text: 0xF2F2F7, neutral: 0x3A3A3C,
        pinky: 0x52407A, ring: 0x2E4C75, middle: 0x2F5C3A, index: 0x7A5024, thumb: 0x245E5A
    )

    private init(background: UInt32, text: UInt32, neutral: UInt32,
                 pinky: UInt32, ring: UInt32, middle: UInt32, index: UInt32, thumb: UInt32) {
        self.background = RGB(background).color
        self.text = RGB(text).color
        let neutralRGB = RGB(neutral)
        soft = [
            .pinky: RGB(pinky).color,
            .ring: RGB(ring).color,
            .middle: RGB(middle).color,
            .index: RGB(index).color,
            .indexInner: RGB(index).mixed(with: neutralRGB, 0.5).color, // same color, paler
            .thumb: RGB(thumb).color,
            .neutral: neutralRGB.color,
        ]
        strong = [
            .pinky: RGB(0x8B5CF6).color,
            .ring: RGB(0x3B82F6).color,
            .middle: RGB(0x22A35A).color,
            .index: RGB(0xF08C1A).color,
            .indexInner: RGB(0xF08C1A).color,
            .thumb: RGB(0x14B8A6).color,
            .neutral: RGB(0x7C7C85).color,
        ]
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
