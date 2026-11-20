import Carbon.HIToolbox
import CoreGraphics
import Testing
@testable import KeyView

struct KeyboardTests {
    @Test(arguments: [KeyboardKind.ansi, .iso])
    func everyRowIsFullWidth(kind: KeyboardKind) {
        let parts = Keyboard.keys(kind).flatMap(\.parts)
        let rows = Dictionary(grouping: parts) { Int($0.minY) }
        #expect(rows.count == 6)
        for row in rows.values {
            #expect(row.map(\.minX).min() == 0)
            #expect(row.map(\.maxX).max() == Keyboard.width)
        }
    }

    @Test(arguments: [KeyboardKind.ansi, .iso])
    func keysDoNotOverlap(kind: KeyboardKind) {
        let keys = Keyboard.keys(kind)
        for i in keys.indices {
            for j in keys.indices where j > i {
                for a in keys[i].parts {
                    for b in keys[j].parts {
                        #expect(a.intersection(b).isEmpty)
                    }
                }
            }
        }
    }

    @Test(arguments: [KeyboardKind.ansi, .iso])
    func keyCodesAreUnique(kind: KeyboardKind) {
        let codes = Keyboard.keys(kind).compactMap(\.code)
        #expect(Set(codes).count == codes.count)
    }

    @Test func fingersFollowSpec() {
        func finger(_ code: Int) -> Finger? {
            Keyboard.ansi.first { $0.code == UInt16(code) }?.finger
        }
        #expect(finger(kVK_ANSI_Q) == .pinky)
        #expect(finger(kVK_ANSI_T) == .indexInner)
        #expect(finger(kVK_ANSI_7) == .index)
        #expect(finger(kVK_ANSI_Y) == .indexInner)
        #expect(finger(kVK_ANSI_Slash) == .pinky)
        #expect(finger(kVK_Space) == .thumb)
        #expect(finger(kVK_Command) == .neutral)
    }

    @Test func isoHasItsOwnKeys() {
        func key(_ code: Int) -> Key? {
            Keyboard.iso.first { $0.code == UInt16(code) }
        }
        #expect(key(kVK_ISO_Section)?.rect.origin == CGPoint(x: 0, y: 1)) // left of 1
        #expect(key(kVK_ANSI_Grave)?.rect.origin == CGPoint(x: 1.25, y: 4)) // right of short left Shift
        #expect(key(kVK_Return)?.extra != nil) // L-shaped
        #expect(Keyboard.ansi.contains { $0.code == UInt16(kVK_ISO_Section) } == false)
    }

    @Test func detectsIsoKeyboard() {
        #expect(KeyboardKind(keyboardType: 92) == .iso) // MacBook ISO
    }

    @Test func cornerShowsShiftSymbolButNotCapitals() {
        #expect(KeyLabels.cornerSymbol(base: "1", shifted: "!") == "!")
        #expect(KeyLabels.cornerSymbol(base: "a", shifted: "A") == nil)
        #expect(KeyLabels.cornerSymbol(base: "ж", shifted: "Ж") == nil)
        #expect(KeyLabels.cornerSymbol(base: "4", shifted: ";") == ";")
    }

    @MainActor @Test func currentLayoutGivesLabels() {
        let labels = LayoutReader.currentLabels(keyboardType: UInt32(LMGetKbdType()))
        #expect(labels[UInt16(kVK_ANSI_A)]?.base.isEmpty == false)
    }
}
