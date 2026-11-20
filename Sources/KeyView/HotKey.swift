import Carbon.HIToolbox

/// System-wide hotkey through Carbon. Needs no permission.
final class HotKey {
    private let action: () -> Void
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    /// `keyCode` is a physical key (`kVK_*`), so the hotkey works in any layout.
    init(keyCode: Int, modifiers: Int, action: @escaping () -> Void) {
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
        let id = EventHotKeyID(signature: OSType(0x4B56_5731), id: 1) // "KVW1"
        RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), id, GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }
}
