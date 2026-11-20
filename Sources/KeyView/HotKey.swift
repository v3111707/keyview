import Carbon.HIToolbox

/// System-wide hotkey through Carbon. Needs no permission.
final class HotKey {
    private let action: () -> Void
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    init(action: @escaping () -> Void) {
        self.action = action
        var pressed = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, info in
                guard let info else { return OSStatus(eventNotHandledErr) }
                Unmanaged<HotKey>.fromOpaque(info).takeUnretainedValue().action()
                return noErr
            },
            1,
            &pressed,
            Unmanaged.passUnretained(self).toOpaque(),
            &handlerRef
        )
    }

    /// Uses `shortcut` instead of the current one. `nil` turns the hotkey off.
    /// Returns `false` if macOS refused the shortcut; then no hotkey is on.
    @discardableResult
    func register(_ shortcut: Shortcut?) -> Bool {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        hotKeyRef = nil
        guard let shortcut else { return true }
        let id = EventHotKeyID(signature: OSType(0x4B56_5731), id: 1) // "KVW1"
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers, id, GetApplicationEventTarget(), 0, &ref)
        guard status == noErr, let ref else { return false }
        hotKeyRef = ref
        return true
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }
}
