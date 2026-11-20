import Carbon.HIToolbox
import CoreGraphics
import Testing
@testable import KeyView

struct KeyboardTests {
    @Test func everyRowIsFullWidth() {
        let rows = Dictionary(grouping: Keyboard.keys) { Int($0.rect.minY) }
        #expect(rows.count == 6)
        for keys in rows.values {
            #expect(keys.map(\.rect.minX).min() == 0)
            #expect(keys.map(\.rect.maxX).max() == Keyboard.width)
        }
    }

    @Test func keysDoNotOverlap() {
        let keys = Keyboard.keys
        for i in keys.indices {
            for j in keys.indices where j > i {
                #expect(keys[i].rect.intersection(keys[j].rect).isEmpty)
            }
        }
    }

    @Test func keyCodesAreUnique() {
        let codes = Keyboard.keys.compactMap(\.code)
        #expect(Set(codes).count == codes.count)
    }

    @Test func fingersFollowSpec() {
        func finger(_ code: Int) -> Finger? {
            Keyboard.keys.first { $0.code == UInt16(code) }?.finger
        }
        #expect(finger(kVK_ANSI_Q) == .pinky)
        #expect(finger(kVK_ANSI_T) == .indexInner)
        #expect(finger(kVK_ANSI_7) == .index)
        #expect(finger(kVK_ANSI_Y) == .indexInner)
        #expect(finger(kVK_ANSI_Slash) == .pinky)
        #expect(finger(kVK_Space) == .thumb)
        #expect(finger(kVK_Command) == .neutral)
    }

    @Test func cornerShowsShiftSymbolButNotCapitals() {
        #expect(KeyLabels.cornerSymbol(base: "1", shifted: "!") == "!")
        #expect(KeyLabels.cornerSymbol(base: "a", shifted: "A") == nil)
        #expect(KeyLabels.cornerSymbol(base: "ж", shifted: "Ж") == nil)
        #expect(KeyLabels.cornerSymbol(base: "4", shifted: ";") == ";")
    }

    @Test func currentLayoutGivesLabels() {
        let labels = LayoutReader.currentLabels()
        #expect(labels[UInt16(kVK_ANSI_A)]?.base.isEmpty == false)
    }
}
