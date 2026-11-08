import AppKit
import Carbon

/// RegisterEventHotKey works system-wide without requesting Accessibility or Input Monitoring.
@MainActor
final class GlobalShortcut {
    private var reference: EventHotKeyRef?
    private var handler: EventHandlerRef?
    var onPress: (() -> Void)?

    @discardableResult
    func register() -> Bool {
        unregister()
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        let installed = InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else { return OSStatus(eventNotHandledErr) }
            MainActor.assumeIsolated {
                Unmanaged<GlobalShortcut>.fromOpaque(userData).takeUnretainedValue().onPress?()
            }
            return noErr
        }, 1, &type, context, &handler)
        guard installed == noErr else { return false }
        let id = EventHotKeyID(signature: 0x53484F54, id: 1)
        let status = RegisterEventHotKey(UInt32(kVK_ANSI_2), UInt32(cmdKey | shiftKey), id,
                                         GetApplicationEventTarget(), 0, &reference)
        if status != noErr { unregister() }
        return status == noErr
    }

    func unregister() {
        if let reference { UnregisterEventHotKey(reference) }
        if let handler { RemoveEventHandler(handler) }
        reference = nil; handler = nil
    }
}
