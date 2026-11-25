import Carbon.HIToolbox
import CoreGraphics
import Foundation

/// Watches key presses in all apps (read only). Needs the Input Monitoring permission.
/// Without it nothing is highlighted and the Shift layer stays off.
final class KeyMonitor {
    private let state: KeyboardState
    private var tap: CFMachPort?
    private var tapSource: CFRunLoopSource?
    /// Input Monitoring was granted when the tap was made. A tap made without it stays dead
    /// even after the user grants it, so it has to be made again.
    private var hadAccess = false
    private var enabled = false
    private var staleCheck: Timer?

    /// Called after a key press changed `state.keyboardType`.
    var onKeyboardTypeChange: (() -> Void)?

    /// `true` after the first key press arrived. Without Input Monitoring none ever does.
    private(set) var seesKeyPresses = false

    /// `true` while the monitor checks that highlighted keys are still held.
    var isCheckingStaleKeys: Bool { staleCheck != nil }

    /// Left and right modifier keys. `bit` is the device-dependent flag of one key
    /// (NX_DEVICE*KEYMASK in IOLLEvent.h), `flag` is set while either side is held.
    private static let modifiers: [(code: UInt16, bit: UInt64, flag: CGEventFlags)] = [
        (UInt16(kVK_Shift), 0x02, .maskShift), (UInt16(kVK_RightShift), 0x04, .maskShift),
        (UInt16(kVK_Control), 0x01, .maskControl), (UInt16(kVK_RightControl), 0x2000, .maskControl),
        (UInt16(kVK_Option), 0x20, .maskAlternate), (UInt16(kVK_RightOption), 0x40, .maskAlternate),
        (UInt16(kVK_Command), 0x08, .maskCommand), (UInt16(kVK_RightCommand), 0x10, .maskCommand),
    ]
    private static let fn = UInt16(kVK_Function)

    init(state: KeyboardState) {
        self.state = state
    }

    deinit {
        staleCheck?.invalidate()
    }

    /// Asks for Input Monitoring (macOS shows its prompt once) and starts listening if allowed.
    func start() {
        hadAccess = CGPreflightListenEventAccess()
        if !hadAccess {
            _ = CGRequestListenEventAccess()
        }
        createTap()
    }

    /// Makes the tap again if the user granted Input Monitoring after it was made.
    /// Otherwise nothing happens.
    func restartIfAccessGranted() {
        guard tap != nil, !hadAccess, CGPreflightListenEventAccess() else { return }
        removeTap()
        hadAccess = true
        createTap()
    }

    private func removeTap() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let tapSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), tapSource, .commonModes) }
        tap = nil
        tapSource = nil
    }

    private func createTap() {
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
            return
        }
        // Without Input Monitoring macOS still gives a tap, but keeps it off and sends it no key presses.
        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        tapSource = source
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

    /// Handles one event from the tap.
    func handle(_ type: CGEventType, _ event: CGEvent) {
        let code = UInt16(truncatingIfNeeded: event.getIntegerValueField(.keyboardEventKeycode))
        switch type {
        case .keyDown:
            seesKeyPresses = true
            // The keyboard type lives only in `state`, so a wrong value there is always corrected.
            let keyboardType = UInt32(truncatingIfNeeded: event.getIntegerValueField(.keyboardEventKeyboardType))
            if keyboardType != 0 && keyboardType != state.keyboardType {
                state.keyboardType = keyboardType
                onKeyboardTypeChange?()
            }
            let key = Keyboard.pressedKey(for: code)
            if !state.pressed.contains(key) { state.pressed.insert(key) }
        case .keyUp:
            let key = Keyboard.pressedKey(for: code)
            if state.pressed.contains(key) { state.pressed.remove(key) }
        case .flagsChanged:
            updateModifiers(event.flags, changedKey: code)
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            // macOS turned the tap off. Turn it back on and forget keys we may have missed.
            if enabled, let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            resetState()
        default:
            break
        }
        updateStaleCheck()
    }

    /// Clears pressed keys and reads the modifier state again.
    private func resetState() {
        state.pressed = []
        updateModifiers(enabled ? CGEventSource.flagsState(.combinedSessionState) : [], changedKey: nil)
        updateStaleCheck()
    }

    private func updateModifiers(_ flags: CGEventFlags, changedKey: UInt16?) {
        var pressed = state.pressed
        for modifier in Self.modifiers {
            if flags.rawValue & modifier.bit != 0 {
                pressed.insert(modifier.code)
            } else {
                pressed.remove(modifier.code)
            }
        }
        // fn has no left/right bit: follow only its own events.
        if changedKey == Self.fn && flags.contains(.maskSecondaryFn) {
            pressed.insert(Self.fn)
        } else if changedKey == Self.fn || changedKey == nil {
            pressed.remove(Self.fn)
        }
        if state.pressed != pressed { state.pressed = pressed }

        let shift = flags.contains(.maskShift)
        if state.shift != shift { state.shift = shift }
        let capsLock = flags.contains(.maskAlphaShift)
        if state.capsLock != capsLock { state.capsLock = capsLock }
    }

    // MARK: Lost releases

    /// macOS sends no key events in password fields and on the lock screen, so the release of a
    /// key can get lost. While something is highlighted, check twice a second that it is still held.
    private func updateStaleCheck() {
        let needed = enabled && (!state.pressed.isEmpty || state.shift)
        if needed && staleCheck == nil {
            let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
                self?.dropStaleKeys()
            }
            timer.tolerance = 0.1
            RunLoop.main.add(timer, forMode: .common)
            staleCheck = timer
        } else if !needed, let timer = staleCheck {
            timer.invalidate()
            staleCheck = nil
        }
    }

    /// Removes the highlight of keys that are not held any more, by the real keyboard state.
    func dropStaleKeys() {
        dropStaleKeys(
            isDown: { CGEventSource.keyState(.combinedSessionState, key: $0) },
            flags: CGEventSource.flagsState(.combinedSessionState),
            secureInput: IsSecureEventInputEnabled()
        )
    }

    /// Removes the highlight of keys that are not held any more. It only removes, never adds.
    /// - Parameters:
    ///   - isDown: tells if a key code is down.
    ///   - flags: modifiers that are held.
    ///   - secureInput: `true` while macOS hides key presses from the app (password field).
    func dropStaleKeys(isDown: (UInt16) -> Bool, flags: CGEventFlags, secureInput: Bool) {
        let pressed = state.pressed.filter { key in
            if let modifier = Self.modifiers.first(where: { $0.code == key }) {
                return flags.contains(modifier.flag)
            }
            if key == Self.fn {
                return !secureInput // fn has no flag to trust here
            }
            return Keyboard.codes(sentBy: key).contains(where: isDown)
        }
        if state.pressed != pressed { state.pressed = pressed }
        if state.shift && !flags.contains(.maskShift) { state.shift = false }
        updateStaleCheck()
    }
}
