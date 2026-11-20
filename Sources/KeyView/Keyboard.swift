import Carbon.HIToolbox
import CoreGraphics

/// Which finger presses a key. Decides the key color.
enum Finger {
    case pinky, ring, middle, index, indexInner, thumb, neutral
}

/// Physical layout of the keyboard the user types on.
enum KeyboardKind {
    case ansi, iso

    /// `keyboardType` is a macOS keyboard type, as from `LMGetKbdType()`. JIS is shown as ANSI.
    init(keyboardType: UInt32) {
        let layout = KBGetLayoutType(Int16(truncatingIfNeeded: keyboardType))
        self = Int(layout) == Int(kKeyboardISO) ? .iso : .ansi
    }
}

/// One physical key of a MacBook keyboard.
struct Key {
    /// Virtual key code (`kVK_*`). `nil` for Touch ID.
    let code: UInt16?
    /// Position and size in key units (1u = one letter key).
    let rect: CGRect
    let finger: Finger
    /// Label of a special key. `nil` means the label comes from the current layout.
    let fixedLabel: String?
    /// Lower part of the L-shaped ISO Return.
    var extra: CGRect? = nil

    var parts: [CGRect] { [rect] + (extra.map { [$0] } ?? []) }
}

/// MacBook keyboard, ANSI or ISO: 6 rows, each 14.5u wide.
enum Keyboard {
    static let width: CGFloat = 14.5
    static let height: CGFloat = 6

    static let ansi = makeKeys(.ansi)
    static let iso = makeKeys(.iso)

    static func keys(_ kind: KeyboardKind) -> [Key] {
        kind == .iso ? iso : ansi
    }

    /// Keys with a tactile bump for the index fingers (F and J).
    static let bumpKeys: Set<UInt16> = [UInt16(kVK_ANSI_F), UInt16(kVK_ANSI_J)]

    private typealias Item = (code: Int?, finger: Finger, width: CGFloat, label: String?)

    private static func key(_ code: Int, _ finger: Finger) -> Item {
        (code, finger, 1, nil)
    }

    private static func special(_ code: Int?, _ label: String, _ finger: Finger = .neutral, width: CGFloat = 1) -> Item {
        (code, finger, width, label)
    }

    private static func makeKeys(_ kind: KeyboardKind) -> [Key] {
        var keys: [Key] = []
        let iso = kind == .iso

        func row(_ y: CGFloat, _ items: [Item]) {
            var x: CGFloat = 0
            for item in items {
                let rect = CGRect(x: x, y: y, width: item.width, height: 1)
                keys.append(Key(code: item.code.map { UInt16($0) }, rect: rect, finger: item.finger, fixedLabel: item.label))
                x += item.width
            }
        }

        let functionKeys = [kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6,
                            kVK_F7, kVK_F8, kVK_F9, kVK_F10, kVK_F11, kVK_F12]
        var functionRow: [Item] = [special(kVK_Escape, "esc", width: 1.5)]
        for (number, code) in functionKeys.enumerated() {
            functionRow.append(special(code, "F\(number + 1)"))
        }
        functionRow.append(special(nil, "")) // Touch ID
        row(0, functionRow)

        row(1, [
            key(iso ? kVK_ISO_Section : kVK_ANSI_Grave, .pinky), key(kVK_ANSI_1, .pinky), key(kVK_ANSI_2, .ring),
            key(kVK_ANSI_3, .middle), key(kVK_ANSI_4, .index), key(kVK_ANSI_5, .indexInner),
            key(kVK_ANSI_6, .indexInner), key(kVK_ANSI_7, .index), key(kVK_ANSI_8, .middle),
            key(kVK_ANSI_9, .ring), key(kVK_ANSI_0, .pinky), key(kVK_ANSI_Minus, .pinky),
            key(kVK_ANSI_Equal, .pinky), special(kVK_Delete, "⌫", .pinky, width: 1.5),
        ])

        var tabRow: [Item] = [
            special(kVK_Tab, "⇥", .pinky, width: 1.5), key(kVK_ANSI_Q, .pinky), key(kVK_ANSI_W, .ring),
            key(kVK_ANSI_E, .middle), key(kVK_ANSI_R, .index), key(kVK_ANSI_T, .indexInner),
            key(kVK_ANSI_Y, .indexInner), key(kVK_ANSI_U, .index), key(kVK_ANSI_I, .middle),
            key(kVK_ANSI_O, .ring), key(kVK_ANSI_P, .pinky), key(kVK_ANSI_LeftBracket, .pinky),
            key(kVK_ANSI_RightBracket, .pinky),
        ]
        if !iso { tabRow.append(key(kVK_ANSI_Backslash, .pinky)) }
        row(2, tabRow)

        var capsRow: [Item] = [
            special(kVK_CapsLock, "⇪", .pinky, width: 1.75), key(kVK_ANSI_A, .pinky), key(kVK_ANSI_S, .ring),
            key(kVK_ANSI_D, .middle), key(kVK_ANSI_F, .index), key(kVK_ANSI_G, .indexInner),
            key(kVK_ANSI_H, .indexInner), key(kVK_ANSI_J, .index), key(kVK_ANSI_K, .middle),
            key(kVK_ANSI_L, .ring), key(kVK_ANSI_Semicolon, .pinky), key(kVK_ANSI_Quote, .pinky),
        ]
        if iso {
            capsRow.append(key(kVK_ANSI_Backslash, .pinky))
            // L-shaped Return: top part ends the tab row, bottom part ends this row.
            keys.append(Key(code: UInt16(kVK_Return), rect: CGRect(x: 13.5, y: 2, width: 1, height: 1),
                            finger: .pinky, fixedLabel: "↩", extra: CGRect(x: 13.75, y: 3, width: 0.75, height: 1)))
        } else {
            capsRow.append(special(kVK_Return, "↩", .pinky, width: 1.75))
        }
        row(3, capsRow)

        var shiftRow: [Item] = iso
            ? [special(kVK_Shift, "⇧", .pinky, width: 1.25), key(kVK_ANSI_Grave, .pinky)]
            : [special(kVK_Shift, "⇧", .pinky, width: 2.25)]
        shiftRow += [
            key(kVK_ANSI_Z, .pinky), key(kVK_ANSI_X, .ring), key(kVK_ANSI_C, .middle),
            key(kVK_ANSI_V, .index), key(kVK_ANSI_B, .indexInner), key(kVK_ANSI_N, .indexInner),
            key(kVK_ANSI_M, .index), key(kVK_ANSI_Comma, .middle), key(kVK_ANSI_Period, .ring),
            key(kVK_ANSI_Slash, .pinky), special(kVK_RightShift, "⇧", .pinky, width: 2.25),
        ]
        row(4, shiftRow)

        row(5, [
            special(kVK_Function, "fn"), special(kVK_Control, "⌃"), special(kVK_Option, "⌥"),
            special(kVK_Command, "⌘", width: 1.25), special(kVK_Space, "", .thumb, width: 5),
            special(kVK_RightCommand, "⌘", width: 1.25), special(kVK_RightOption, "⌥"),
        ])

        // Inverted-T arrows: half-height keys at the end of the bottom row.
        let x = keys[keys.count - 1].rect.maxX
        let arrows: [(code: Int, label: String, x: CGFloat, y: CGFloat)] = [
            (kVK_LeftArrow, "◀", x, 5.5), (kVK_UpArrow, "▲", x + 1, 5),
            (kVK_DownArrow, "▼", x + 1, 5.5), (kVK_RightArrow, "▶", x + 2, 5.5),
        ]
        for arrow in arrows {
            let rect = CGRect(x: arrow.x, y: arrow.y, width: 1, height: 0.5)
            keys.append(Key(code: UInt16(arrow.code), rect: rect, finger: .neutral, fixedLabel: arrow.label))
        }
        return keys
    }
}
