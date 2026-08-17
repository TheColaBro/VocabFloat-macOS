import AppKit
import Carbon

@MainActor
final class GlobalHotKeyManager {
    static let shared = GlobalHotKeyManager()

    private var eventHandler: EventHandlerRef?
    private var lookupHotKeyRef: EventHotKeyRef?
    private var highlightHotKeyRef: EventHotKeyRef?

    private var onLookupTrigger: (() -> Void)?
    private var onHighlightTrigger: (() -> Void)?

    private init() {}

    func register(onLookup: @escaping () -> Void, onExtractHighlight: @escaping () -> Void) {
        self.onLookupTrigger = onLookup
        self.onHighlightTrigger = onExtractHighlight

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )

        let handlerBlock: EventHandlerUPP = { _, event, _ -> OSStatus in
            guard let event = event else { return noErr }
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )

            if status == noErr {
                Task { @MainActor in
                    if hotKeyID.id == 1 {
                        GlobalHotKeyManager.shared.onLookupTrigger?()
                    } else if hotKeyID.id == 2 {
                        GlobalHotKeyManager.shared.onHighlightTrigger?()
                    }
                }
            }
            return noErr
        }

        InstallEventHandler(
            GetEventDispatcherTarget(),
            handlerBlock,
            1,
            &eventType,
            nil,
            &eventHandler
        )

        // 1. 注册 ⌥D (Option+D, KeyCode 2 = kVK_ANSI_D) -> 查词
        let lookupID = EventHotKeyID(signature: OSType(0x564F4342), id: 1) // "VOCB"
        RegisterEventHotKey(
            UInt32(kVK_ANSI_D),
            UInt32(optionKey),
            lookupID,
            GetEventDispatcherTarget(),
            0,
            &lookupHotKeyRef
        )

        // 2. 注册 ⌥N (Option+N, KeyCode 45 = kVK_ANSI_N) -> 提取当前 Preview 高亮笔记
        let highlightID = EventHotKeyID(signature: OSType(0x564F4342), id: 2) // "VOCB"
        RegisterEventHotKey(
            UInt32(kVK_ANSI_N),
            UInt32(optionKey),
            highlightID,
            GetEventDispatcherTarget(),
            0,
            &highlightHotKeyRef
        )
    }
}
