import AppKit
import Carbon.HIToolbox

/// A user-defined shortcut (key + modifiers) that works on every keyboard.
/// The built-in `fn` shortcuts only fire on Apple keyboards, because third-party
/// keyboards handle their Fn key in firmware and never report it to macOS.
struct KeyCombo: Codable, Hashable {
    var keyCode: UInt32
    /// Raw value of `NSEvent.ModifierFlags`, limited to Command, Option, Control and Shift.
    var modifierFlags: UInt
    var keyLabel: String

    static let supportedModifiers: NSEvent.ModifierFlags = [.command, .option, .control, .shift]

    var modifiers: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: modifierFlags).intersection(Self.supportedModifiers)
    }

    var carbonModifiers: UInt32 {
        var result: UInt32 = 0
        if modifiers.contains(.command) { result |= UInt32(cmdKey) }
        if modifiers.contains(.option) { result |= UInt32(optionKey) }
        if modifiers.contains(.control) { result |= UInt32(controlKey) }
        if modifiers.contains(.shift) { result |= UInt32(shiftKey) }
        return result
    }

    /// Label for `HotkeyBadge`, which splits on " + ".
    var displayLabel: String {
        var parts: [String] = []
        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        if modifiers.contains(.command) { parts.append("⌘") }
        parts.append(keyLabel)
        return parts.joined(separator: " + ")
    }

    enum CaptureResult {
        case combo(KeyCombo)
        case cancelled
        case needsModifier
        /// A shortcut every app relies on, e.g. Command-V. As a global shortcut of Diktat it
        /// would stop working everywhere else.
        case reserved
    }

    /// Command (with or without Shift) plus one of these keys: copy, paste, cut, undo, select
    /// all, save, quit, close, hide, minimize, new, open, print, find, tab, space, and the
    /// comma of "Settings".
    private static let reservedCommandKeys: Set<Int> = [
        kVK_ANSI_C, kVK_ANSI_V, kVK_ANSI_X, kVK_ANSI_Z, kVK_ANSI_A, kVK_ANSI_S, kVK_ANSI_Q, kVK_ANSI_W,
        kVK_ANSI_H, kVK_ANSI_M, kVK_ANSI_N, kVK_ANSI_O, kVK_ANSI_P, kVK_ANSI_F, kVK_ANSI_T, kVK_Tab, kVK_Space,
        kVK_ANSI_Comma,
    ]

    /// True for the shortcuts macOS and nearly every app use themselves.
    var isReserved: Bool {
        let flags = modifiers
        guard flags == [.command] || flags == [.command, .shift] else { return false }
        return Self.reservedCommandKeys.contains(Int(keyCode))
    }

    /// Builds a combo from a key-down event captured in the settings.
    static func capture(from event: NSEvent) -> CaptureResult {
        let keyCode = UInt32(event.keyCode)
        if keyCode == UInt32(kVK_Escape) {
            return .cancelled
        }

        let modifiers = event.modifierFlags.intersection(supportedModifiers)
        let isFunctionKey = functionKeyLabels[keyCode] != nil
        // Shift alone would collide with normal typing.
        guard isFunctionKey || !modifiers.subtracting(.shift).isEmpty else {
            return .needsModifier
        }

        let combo = KeyCombo(
            keyCode: keyCode,
            modifierFlags: modifiers.rawValue,
            keyLabel: label(for: event)
        )
        return combo.isReserved ? .reserved : .combo(combo)
    }

    private static func label(for event: NSEvent) -> String {
        let keyCode = UInt32(event.keyCode)
        if let label = functionKeyLabels[keyCode] ?? specialKeyLabels[keyCode] {
            return label
        }
        let characters = event.charactersIgnoringModifiers?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased() ?? ""
        return characters.isEmpty ? String(localized: "Taste \(keyCode)") : characters
    }

    private static let specialKeyLabels: [UInt32: String] = [
        UInt32(kVK_Space): "Space",
        UInt32(kVK_Return): "↩",
        UInt32(kVK_Tab): "⇥",
        UInt32(kVK_Delete): "⌫",
        UInt32(kVK_ForwardDelete): "⌦",
        UInt32(kVK_LeftArrow): "←",
        UInt32(kVK_RightArrow): "→",
        UInt32(kVK_UpArrow): "↑",
        UInt32(kVK_DownArrow): "↓",
        UInt32(kVK_Home): "↖",
        UInt32(kVK_End): "↘",
        UInt32(kVK_PageUp): "⇞",
        UInt32(kVK_PageDown): "⇟",
    ]

    private static let functionKeyLabels: [UInt32: String] = [
        UInt32(kVK_F1): "F1", UInt32(kVK_F2): "F2", UInt32(kVK_F3): "F3", UInt32(kVK_F4): "F4",
        UInt32(kVK_F5): "F5", UInt32(kVK_F6): "F6", UInt32(kVK_F7): "F7", UInt32(kVK_F8): "F8",
        UInt32(kVK_F9): "F9", UInt32(kVK_F10): "F10", UInt32(kVK_F11): "F11", UInt32(kVK_F12): "F12",
        UInt32(kVK_F13): "F13", UInt32(kVK_F14): "F14", UInt32(kVK_F15): "F15", UInt32(kVK_F16): "F16",
        UInt32(kVK_F17): "F17", UInt32(kVK_F18): "F18", UInt32(kVK_F19): "F19",
    ]
}

/// Registers global shortcuts through Carbon's `RegisterEventHotKey`.
/// Unlike an event monitor this swallows the key press, keeps working under
/// Secure Event Input and needs no Accessibility permission.
final class CarbonHotkeyRegistrar {
    /// Called on the main thread with the hotkey id and whether it was pressed (true) or released.
    var onEvent: ((UInt32, Bool) -> Void)?

    private var hotkeyRefs: [UInt32: EventHotKeyRef] = [:]
    private var handlerRef: EventHandlerRef?
    private static let signature: OSType = 0x424C_5458 // "BLTX"

    init() {
        var eventTypes = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased)),
        ]
        let userData = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData -> OSStatus in
                guard let event, let userData else { return OSStatus(eventNotHandledErr) }
                var hotkeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotkeyID
                )
                guard status == noErr, hotkeyID.signature == CarbonHotkeyRegistrar.signature else {
                    return OSStatus(eventNotHandledErr)
                }
                let registrar = Unmanaged<CarbonHotkeyRegistrar>.fromOpaque(userData).takeUnretainedValue()
                registrar.onEvent?(hotkeyID.id, GetEventKind(event) == UInt32(kEventHotKeyPressed))
                return noErr
            },
            eventTypes.count,
            &eventTypes,
            userData,
            &handlerRef
        )
    }

    /// Returns false when macOS refused the registration.
    @discardableResult
    func register(id: UInt32, combo: KeyCombo) -> Bool {
        unregister(id: id)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            combo.keyCode,
            combo.carbonModifiers,
            EventHotKeyID(signature: Self.signature, id: id),
            GetApplicationEventTarget(),
            0,
            &ref
        )
        guard status == noErr, let ref else { return false }
        hotkeyRefs[id] = ref
        return true
    }

    func unregister(id: UInt32) {
        if let ref = hotkeyRefs.removeValue(forKey: id) {
            UnregisterEventHotKey(ref)
        }
    }

    func unregisterAll() {
        for ref in hotkeyRefs.values {
            UnregisterEventHotKey(ref)
        }
        hotkeyRefs.removeAll()
    }

    deinit {
        unregisterAll()
        if let handlerRef {
            RemoveEventHandler(handlerRef)
        }
    }
}
