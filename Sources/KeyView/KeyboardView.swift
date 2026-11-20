import Carbon.HIToolbox
import SwiftUI

/// Content of the keyboard window: the keyboard in the theme picked in Settings.
struct LiveKeyboardView: View {
    @ObservedObject var state: KeyboardState
    @ObservedObject var settings: AppSettings

    var body: some View {
        KeyboardView(state: state, theme: settings.theme)
    }
}

/// Draws the keyboard in one theme. Everything scales with the view.
struct KeyboardView: View {
    @ObservedObject var state: KeyboardState
    let theme: Theme
    @Environment(\.colorScheme) private var colorScheme

    /// Space around the keys, in key units.
    static let padding: CGFloat = 0.3
    /// Size of the whole view in key units.
    static let aspect = CGSize(width: Keyboard.width + 2 * padding, height: Keyboard.height + 2 * padding)

    var body: some View {
        let palette = theme.palette(dark: colorScheme == .dark)
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
        let parts = key.parts.map {
            CGRect(x: origin.x + $0.minX * u, y: origin.y + $0.minY * u, width: $0.width * u, height: $0.height * u)
                .insetBy(dx: gap, dy: gap)
        }
        let rect = parts[0]
        let look = theme.look(key.finger, pressed: isPressed(key), in: palette)
        let shape = Self.shape(of: parts, radius: theme.cornerRadius * u)
        if let fill = look.fill {
            context.fill(shape, with: .color(fill))
        }
        if let stroke = look.stroke {
            context.stroke(shape, with: .color(stroke), lineWidth: 0.04 * u)
        }
        if let bar = look.bar {
            let bottom = parts[parts.count - 1]
            let line = CGRect(x: bottom.minX + 0.12 * u, y: bottom.maxY - 0.12 * u,
                              width: bottom.width - 0.24 * u, height: 0.06 * u)
            context.fill(Path(roundedRect: line, cornerRadius: 0.03 * u), with: .color(bar))
        }

        let ink = look.ink
        if let code = key.code, Keyboard.bumpKeys.contains(code) {
            // Tactile bump, like on the real key. Above the bar if there is one.
            let lift = (look.bar == nil ? 0.16 : 0.25) * u
            let bump = CGRect(x: rect.midX - 0.13 * u, y: rect.maxY - lift, width: 0.26 * u, height: 0.05 * u)
            context.fill(Path(roundedRect: bump, cornerRadius: 0.025 * u), with: .color(ink.opacity(0.6)))
        }

        func text(_ string: String, size: CGFloat, design: Font.Design) -> Text {
            Text(string).font(.system(size: size * u, weight: look.bold ? .semibold : .regular, design: design))
        }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        if let label = key.fixedLabel {
            // Signs like ⇪ come out too small in a monospaced font, so special keys keep the default one.
            let size: CGFloat = key.rect.height < 1 ? 0.22 : 0.28
            context.draw(text(label, size: size, design: .default).foregroundStyle(ink), at: center)
        } else if let code = key.code, let labels = state.labels[code] {
            let main = labels.main(shift: state.shift, caps: state.capsLock)
            context.draw(text(main, size: 0.42, design: theme.fontDesign).foregroundStyle(ink), at: center)
            if !state.shift, let corner = labels.corner {
                context.draw(text(corner, size: 0.24, design: theme.fontDesign).foregroundStyle(ink.opacity(0.45)),
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

    /// Outline of a key. Two parts make the L-shaped ISO Return.
    static func shape(of parts: [CGRect], radius: CGFloat) -> Path {
        guard parts.count == 2 else {
            return Path(roundedRect: parts[0], cornerRadius: radius, style: .continuous)
        }
        let top = parts[0]
        let bottom = parts[1]
        return roundedPolygon([
            CGPoint(x: top.minX, y: top.minY), CGPoint(x: top.maxX, y: top.minY),
            CGPoint(x: bottom.maxX, y: bottom.maxY), CGPoint(x: bottom.minX, y: bottom.maxY),
            CGPoint(x: bottom.minX, y: top.maxY), CGPoint(x: top.minX, y: top.maxY),
        ], radius: radius)
    }

    private static func roundedPolygon(_ points: [CGPoint], radius: CGFloat) -> Path {
        func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }
        let count = points.count
        var path = Path()
        let last = points[count - 1]
        path.move(to: CGPoint(x: (last.x + points[0].x) / 2, y: (last.y + points[0].y) / 2))
        for index in 0..<count {
            let previous = points[(index + count - 1) % count]
            let corner = points[index]
            let next = points[(index + 1) % count]
            // A corner may use at most half of each side, or the arcs would overlap.
            let r = min(radius, distance(previous, corner) / 2, distance(corner, next) / 2)
            path.addArc(tangent1End: corner, tangent2End: next, radius: r)
        }
        path.closeSubpath()
        return path
    }
}
