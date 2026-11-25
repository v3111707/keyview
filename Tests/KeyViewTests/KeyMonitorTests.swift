import Carbon.HIToolbox
import CoreGraphics
import Testing
@testable import KeyView

@MainActor
struct KeyMonitorTests {
    let state = KeyboardState()
    let monitor: KeyMonitor

    init() {
        monitor = KeyMonitor(state: state)
    }

    /// A key event that is never posted, only handed to the monitor.
    private func event(_ code: Int, flags: CGEventFlags = [], keyboardType: Int64 = 40) throws -> CGEvent {
        let event = try #require(CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(code), keyDown: true))
        event.flags = flags
        event.setIntegerValueField(.keyboardEventKeyboardType, value: keyboardType)
        return event
    }

    private func key(_ code: Int) -> UInt16 { UInt16(code) }

    /// Left Shift is down: the shared Shift flag plus the device bit of the left key.
    private let leftShift: CGEventFlags = [.maskShift, CGEventFlags(rawValue: 0x02)]

    // MARK: Keyboard type

    @Test func keyPressCorrectsKeyboardTypeChangedElsewhere() throws {
        var changes = 0
        monitor.onKeyboardTypeChange = { changes += 1 }
        #expect(monitor.seesKeyPresses == false)

        monitor.handle(.keyDown, try event(kVK_ANSI_A, keyboardType: 40))
        #expect(state.keyboardType == 40)
        #expect(monitor.seesKeyPresses)

        state.keyboardType = 92 // the app took another type from macOS, as on showing the window
        monitor.handle(.keyDown, try event(kVK_ANSI_A, keyboardType: 40))
        #expect(state.keyboardType == 40)
        #expect(changes == 2)

        monitor.handle(.keyDown, try event(kVK_ANSI_S, keyboardType: 40))
        #expect(changes == 2) // same keyboard, nothing to do
    }

    @Test func restartWithoutTapDoesNothing() throws {
        monitor.handle(.keyDown, try event(kVK_ANSI_A))
        monitor.restartIfAccessGranted() // start() was never called, there is no tap to remake
        #expect(state.pressed == [key(kVK_ANSI_A)])
        #expect(monitor.seesKeyPresses)
    }

    // MARK: fn combinations

    @Test func fnCombinationHighlightsThePressedKey() throws {
        let pairs = [
            (kVK_Home, kVK_LeftArrow), (kVK_End, kVK_RightArrow), (kVK_PageUp, kVK_UpArrow),
            (kVK_PageDown, kVK_DownArrow), (kVK_ForwardDelete, kVK_Delete), (kVK_ANSI_KeypadEnter, kVK_Return),
        ]
        for (sent, pressed) in pairs {
            monitor.handle(.keyDown, try event(sent))
            #expect(state.pressed == [key(pressed)])
            monitor.handle(.keyUp, try event(sent))
            #expect(state.pressed.isEmpty)
        }
    }

    @Test func fnReleasedBeforeTheKeyStillClearsTheHighlight() throws {
        monitor.handle(.keyDown, try event(kVK_Home)) // fn+←
        monitor.handle(.keyUp, try event(kVK_LeftArrow)) // fn went up first, so the release is a plain ←
        #expect(state.pressed.isEmpty)
    }

    @Test func fnCodesPointToDrawnKeys() {
        for kind in [KeyboardKind.ansi, .iso] {
            let drawn = Set(Keyboard.keys(kind).compactMap(\.code))
            #expect(Set(Keyboard.fnCodes.values).isSubset(of: drawn))
            #expect(Set(Keyboard.fnCodes.keys).isDisjoint(with: drawn))
        }
    }

    // MARK: Lost releases

    @Test func keyReleasedWithoutEventLosesHighlight() throws {
        monitor.handle(.keyDown, try event(kVK_Tab)) // Tab into a password field, release is not sent
        monitor.dropStaleKeys(isDown: { _ in false }, flags: [], secureInput: true)
        #expect(state.pressed.isEmpty)
    }

    @Test func modifierReleasedWithoutEventLosesHighlightAndShiftLayer() throws {
        monitor.handle(.flagsChanged, try event(kVK_Shift, flags: leftShift))
        #expect(state.pressed == [key(kVK_Shift)])
        #expect(state.shift)

        monitor.dropStaleKeys(isDown: { _ in false }, flags: [], secureInput: true)
        #expect(state.pressed.isEmpty)
        #expect(state.shift == false)
    }

    @Test func heldKeysKeepHighlight() throws {
        monitor.handle(.keyDown, try event(kVK_ANSI_A))
        monitor.handle(.keyDown, try event(kVK_Home)) // fn+← is held, the system sees Home
        monitor.handle(.flagsChanged, try event(kVK_Shift, flags: leftShift))

        let down: Set<UInt16> = [key(kVK_ANSI_A), key(kVK_Home)]
        monitor.dropStaleKeys(isDown: { down.contains($0) }, flags: .maskShift, secureInput: false)

        #expect(state.pressed == [key(kVK_ANSI_A), key(kVK_LeftArrow), key(kVK_Shift)])
        #expect(state.shift)
    }

    @Test func fnLosesHighlightOnlyWhenKeyPressesAreHidden() throws {
        monitor.handle(.flagsChanged, try event(kVK_Function, flags: .maskSecondaryFn))
        monitor.dropStaleKeys(isDown: { _ in false }, flags: [], secureInput: false)
        #expect(state.pressed == [key(kVK_Function)])

        monitor.dropStaleKeys(isDown: { _ in false }, flags: [], secureInput: true)
        #expect(state.pressed.isEmpty)
    }

    @Test func realKeyboardStateDropsKeyThatIsNotHeld() throws {
        monitor.handle(.keyDown, try event(kVK_F20)) // nobody holds F20
        monitor.dropStaleKeys()
        #expect(state.pressed.isEmpty)
    }

    @Test func checksForLostReleasesOnlyWhileSomethingIsHighlighted() throws {
        monitor.setEnabled(true)
        #expect(monitor.isCheckingStaleKeys == false)

        monitor.handle(.keyDown, try event(kVK_ANSI_A))
        #expect(monitor.isCheckingStaleKeys)

        monitor.handle(.keyUp, try event(kVK_ANSI_A))
        #expect(monitor.isCheckingStaleKeys == false)
    }
}
