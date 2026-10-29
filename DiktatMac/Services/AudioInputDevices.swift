import CoreAudio
import Foundation
import Observation

/// The microphones of this Mac, read from Core Audio. Nothing here changes a system setting.
enum AudioInputDevices {
    /// The microphone picked in the settings (its UID), or nil for the Mac's default input.
    /// Set by AppState; the recorders read it when a recording starts.
    nonisolated(unsafe) static var preferredUID: String?

    /// Real microphones. Virtual devices (the audio drivers of Teams, NoMachine and the like)
    /// are left out; they would only clutter the list and are no microphone for dictation.
    static func all() -> [InputDevice] {
        deviceIDs().compactMap { id in
            guard inputChannelCount(of: id) > 0,
                  transportType(of: id) != kAudioDeviceTransportTypeVirtual,
                  let uid = string(kAudioDevicePropertyDeviceUID, of: id),
                  let name = string(kAudioObjectPropertyName, of: id)
            else { return nil }
            return InputDevice(uid: uid, name: name)
        }
    }

    /// The Core Audio device of the picked microphone, when it is connected.
    static func preferredDeviceID() -> AudioDeviceID? {
        guard case .device(let device) = MicrophoneSelection.resolve(preferredUID: preferredUID, available: all()) else {
            return nil
        }
        return deviceIDs().first { string(kAudioDevicePropertyDeviceUID, of: $0) == device.uid }
    }

    static func defaultDeviceName() -> String? {
        var device = AudioObjectID(kAudioObjectUnknown)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device)
        guard status == noErr, device != kAudioObjectUnknown else { return nil }
        return string(kAudioObjectPropertyName, of: device)
    }

    private static func deviceIDs() -> [AudioDeviceID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size) == noErr else {
            return []
        }
        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &ids) == noErr else {
            return []
        }
        return ids
    }

    private static func transportType(of device: AudioObjectID) -> UInt32 {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var type: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        AudioObjectGetPropertyData(device, &address, 0, nil, &size, &type)
        return type
    }

    private static func inputChannelCount(of device: AudioDeviceID) -> Int {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(device, &address, 0, nil, &size) == noErr, size > 0 else { return 0 }
        let buffer = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { buffer.deallocate() }
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, buffer) == noErr else { return 0 }
        let list = UnsafeMutableAudioBufferListPointer(buffer.assumingMemoryBound(to: AudioBufferList.self))
        return list.reduce(0) { $0 + Int($1.mNumberChannels) }
    }

    private static func string(_ selector: AudioObjectPropertySelector, of device: AudioObjectID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr, let value else { return nil }
        return value.takeRetainedValue() as String
    }
}

/// A registered Core Audio listener; it unregisters itself when it goes away.
private final class AudioPropertyListener {
    private var address: AudioObjectPropertyAddress
    private let block: AudioObjectPropertyListenerBlock

    init?(selector: AudioObjectPropertySelector, onChange: @escaping @Sendable () -> Void) {
        address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        block = { _, _ in onChange() }
        guard AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, .main, block) == noErr else {
            return nil
        }
    }

    deinit {
        AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, .main, block)
    }
}

/// The list of microphones for a picker. It updates itself when a device is plugged in or
/// removed, or when the default input changes.
@MainActor
@Observable
final class AudioInputDeviceList {
    private(set) var devices: [InputDevice] = AudioInputDevices.all()
    private(set) var defaultName: String? = AudioInputDevices.defaultDeviceName()

    @ObservationIgnored private var listeners: [AudioPropertyListener] = []

    init() {
        listeners = [kAudioHardwarePropertyDevices, kAudioHardwarePropertyDefaultInputDevice].compactMap { selector in
            AudioPropertyListener(selector: selector) { [weak self] in
                Task { @MainActor in self?.refresh() }
            }
        }
    }

    func refresh() {
        devices = AudioInputDevices.all()
        defaultName = AudioInputDevices.defaultDeviceName()
    }
}
