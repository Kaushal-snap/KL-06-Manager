import AppKit
import Carbon

// Pure policy/latch logic is tested without registering or observing a real key.
enum F13WindowAction: Equatable { case show, hide, focusDialog }
enum F13WindowPolicy {
    static func action(appIsActive: Bool, windowIsVisible: Bool, windowIsMiniaturized: Bool, hasDialog: Bool) -> F13WindowAction {
        if hasDialog { return .focusDialog }
        return appIsActive && windowIsVisible && !windowIsMiniaturized ? .hide : .show
    }
}
struct F13PressLatch {
    private(set) var isDown = false
    mutating func update(pressed: Bool) -> Bool {
        let fire = pressed && !isDown
        isDown = pressed
        return fire
    }
    mutating func reset() { isDown = false }
}

// Carbon reserves this one shortcut only while the app is running. No event tap,
// keyboard remapping, Accessibility/Input Monitoring request or keystroke log.
final class F13HotKey {
    static let keyCode: UInt32 = 105 // macOS virtual F13; owner's physical PrtSc.
    static let modifiers: UInt32 = 0 // F13 alone, not Command/Option/Control/Shift.
    fileprivate static let signature: OSType = 0x4B4C3036 // 'KL06', not a device ID.
    fileprivate static let identifier: UInt32 = 1
    private var hotKeyReference: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var latch = F13PressLatch()
    private let onPressed: () -> Void
    var isRegistered: Bool { hotKeyReference != nil }

    init(onPressed: @escaping () -> Void) { self.onPressed = onPressed }

    @discardableResult func register() -> OSStatus {
        unregister()
        let events = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
        ]
        let target = GetApplicationEventTarget()
        let handlerStatus = events.withUnsafeBufferPointer { buffer in
            InstallEventHandler(target, kl06F13EventHandler, buffer.count, buffer.baseAddress,
                                Unmanaged.passUnretained(self).toOpaque(), &eventHandler)
        }
        guard handlerStatus == noErr, eventHandler != nil else {
            unregister()
            return handlerStatus == noErr ? OSStatus(paramErr) : handlerStatus
        }
        let keyID = EventHotKeyID(signature: Self.signature, id: Self.identifier)
        let status = RegisterEventHotKey(Self.keyCode, Self.modifiers, keyID, target, 0, &hotKeyReference)
        guard status == noErr, hotKeyReference != nil else {
            unregister() // Also remove the installed handler on partial failure.
            return status == noErr ? OSStatus(paramErr) : status
        }
        return OSStatus(noErr)
    }

    func unregister() {
        if let reference = hotKeyReference {
            hotKeyReference = nil
            _ = UnregisterEventHotKey(reference) // Only our own returned reference.
        }
        if let handler = eventHandler {
            eventHandler = nil
            _ = RemoveEventHandler(handler)
        }
        latch.reset()
    }

    fileprivate func receive(pressed: Bool) {
        // Carbon application-target handlers run on the main application loop.
        // Holding F13 down must not alternate the window on key autorepeat.
        guard isRegistered, latch.update(pressed: pressed) else { return }
        onPressed()
    }
    deinit { unregister() }
}

private func kl06F13EventHandler(_ nextHandler: EventHandlerCallRef?, _ event: EventRef?, _ context: UnsafeMutableRawPointer?) -> OSStatus {
    guard let event = event, let context = context,
          GetEventClass(event) == OSType(kEventClassKeyboard) else { return OSStatus(eventNotHandledErr) }
    var keyID = EventHotKeyID(signature: 0, id: 0)
    let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                   nil, numericCast(MemoryLayout<EventHotKeyID>.size), nil, &keyID)
    guard status == noErr, keyID.signature == F13HotKey.signature, keyID.id == F13HotKey.identifier else {
        return OSStatus(eventNotHandledErr)
    }
    let kind = GetEventKind(event)
    guard kind == UInt32(kEventHotKeyPressed) || kind == UInt32(kEventHotKeyReleased) else { return OSStatus(eventNotHandledErr) }
    let hotKey = Unmanaged<F13HotKey>.fromOpaque(context).takeUnretainedValue()
    hotKey.receive(pressed: kind == UInt32(kEventHotKeyPressed))
    return OSStatus(noErr)
}
