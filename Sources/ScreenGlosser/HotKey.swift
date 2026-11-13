import AppKit
import Carbon.HIToolbox

/// Global hotkey via Carbon's RegisterEventHotKey, which needs no Accessibility permission.
final class HotKey {
    static let kVK_ANSI_P: UInt32 = UInt32(Carbon.kVK_ANSI_P)

    private static var handlers: [UInt32: () -> Void] = [:]
    private static var nextID: UInt32 = 1
    private static var eventHandlerInstalled = false

    private var ref: EventHotKeyRef?
    private let id: UInt32

    init?(keyCode: UInt32, modifiers: NSEvent.ModifierFlags, action: @escaping () -> Void) {
        HotKey.installHandlerIfNeeded()
        id = HotKey.nextID
        HotKey.nextID += 1

        var carbonMods: UInt32 = 0
        if modifiers.contains(.command) { carbonMods |= UInt32(cmdKey) }
        if modifiers.contains(.option)  { carbonMods |= UInt32(optionKey) }
        if modifiers.contains(.control) { carbonMods |= UInt32(controlKey) }
        if modifiers.contains(.shift)   { carbonMods |= UInt32(shiftKey) }

        let hotKeyID = EventHotKeyID(signature: OSType(0x53474C53) /* 'SGLS' */, id: id)
        let status = RegisterEventHotKey(keyCode, carbonMods, hotKeyID, GetApplicationEventTarget(), 0, &ref)
        guard status == noErr else {
            NSLog("ScreenGlosser: failed to register hotkey (\(status))")
            return nil
        }
        HotKey.handlers[id] = action
    }

    deinit {
        if let ref { UnregisterEventHotKey(ref) }
        HotKey.handlers[id] = nil
    }

    private static func installHandlerIfNeeded() {
        guard !eventHandlerInstalled else { return }
        eventHandlerInstalled = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
            var hkID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &hkID)
            DispatchQueue.main.async { HotKey.handlers[hkID.id]?() }
            return noErr
        }, 1, &spec, nil, nil)
    }
}
