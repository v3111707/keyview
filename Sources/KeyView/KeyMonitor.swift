import Carbon.HIToolbox
import CoreGraphics

/// Watches key presses in all apps (read only). Needs the Input Monitoring permission.
/// Without it nothing is highlighted and the Shift layer stays off.
final class KeyMonitor {
    private let state: KeyboardState
    private var tap: CFMachPort?
    private var enabled = false

    /// Device-dependent flag bits (NX_DEVICE*KEYMASK in IOLLEvent.h) tell left and right modifiers apart.
    private static let modifierBits: [Int: UInt64] = [
        kVK_Shift: 0x02, kVK_RightShift: 0x04,
        kVK_Control: 0x01, kVK_RightControl: 0x2000,
        kVK_Option: 0x20, kVK_RightOption: 0x40,
        kVK_Command: 0x08, kVK_RightCommand: 0x10,
    ]

    init(state: KeyboardState) {
        self.state = state
    }

    /// Asks for Input Monitoring (macOS shows its prompt once) and starts listening if allowed.
    func start() {
        if !CGPreflightListenEventAccess() {
            _ = CGRequestListenEventAccess()
        }
        let types: [CGEventType] = [.keyDown, .keyUp, .flagsChanged]
        let mask = types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, info in
                if let info {
                    Unmanaged<KeyMonitor>.fromOpaque(info).takeUnretainedValue().handle(type, event)
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return // no permission yet
        }
        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        setEnabled(true)
    }

    /// Listening is off while the window is hidden.
    func setEnabled(_ on: Bool) {
        enabled = on
        guard let tap else { return }
        CGEvent.tapEnable(tap: tap, enable: on)
        resetState()
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) {
        let code = UInt16(truncatingIfNeeded: event.getIntegerValueField(.keyboardEventKeycode))
        switch type {
        case .keyDown:
            if !state.pressed.contains(code) { state.pressed.insert(code) }
        case .keyUp:
            if state.pressed.contains(code) { state.pressed.remove(code) }
        case .flagsChanged:
            updateModifiers(event.flags, changedKey: code)
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            // macOS turned the tap off. Turn it back on and forget keys we may have missed.
            if enabled, let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            resetState()
        default:
            break
        }
    }

    /// Clears pressed keys and reads the modifier state again.
    private func resetState() {
        state.pressed = []
        updateModifiers(enabled ? CGEventSource.flagsState(.combinedSessionState) : [], changedKey: nil)
    }

    private func updateModifiers(_ flags: CGEventFlags, changedKey: UInt16?) {
        var pressed = state.pressed
        for (code, bit) in Self.modifierBits {
            if flags.rawValue & bit != 0 {
                pressed.insert(UInt16(code))
            } else {
                pressed.remove(UInt16(code))
            }
        }
        // fn has no left/right bit: follow only its own events.
        let fn = UInt16(kVK_Function)
        if changedKey == fn && flags.contains(.maskSecondaryFn) {
            pressed.insert(fn)
        } else if changedKey == fn || changedKey == nil {
            pressed.remove(fn)
        }
        if state.pressed != pressed { state.pressed = pressed }

        let shift = flags.contains(.maskShift)
        if state.shift != shift { state.shift = shift }
        let capsLock = flags.contains(.maskAlphaShift)
        if state.capsLock != capsLock { state.capsLock = capsLock }
    }
}
