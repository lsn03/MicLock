import CoreAudio
import Foundation

enum DeviceTransport {
    case builtIn, bluetooth, usb, aggregate, virtual, other

    var sfSymbol: String {
        switch self {
        case .builtIn:   return "laptopcomputer"
        case .bluetooth: return "wave.3.right"
        case .usb:       return "cable.connector"
        case .aggregate: return "square.stack.3d.up"
        case .virtual:   return "waveform"
        case .other:     return "dot.radiowaves.left.and.right"
        }
    }
}

struct AudioDevice: Equatable {
    let id: AudioDeviceID
    let uid: String
    let name: String
    let transport: DeviceTransport
}

final class AudioController {
    private let lockedKey   = "lockedInputUID"
    private let enabledKey  = "lockEnabled"
    private let queue = DispatchQueue(label: "MicLock.audio")

    var onDevicesChanged: (() -> Void)?

    private(set) var lockedUID: String? {
        didSet { UserDefaults.standard.set(lockedUID, forKey: lockedKey) }
    }

    private(set) var lockEnabled: Bool {
        didSet { UserDefaults.standard.set(lockEnabled, forKey: enabledKey) }
    }

    init() {
        self.lockedUID   = UserDefaults.standard.string(forKey: lockedKey)
        let d = UserDefaults.standard
        self.lockEnabled = d.object(forKey: enabledKey) as? Bool ?? true
        installListeners()
        enforce()
    }

    // MARK: - Public

    func inputDevices() -> [AudioDevice] {
        allDevices().filter { isInput(deviceID: $0.id) }
    }

    func outputDevices() -> [AudioDevice] {
        allDevices().filter { isOutput(deviceID: $0.id) }
    }

    func currentDefaultInputUID() -> String? {
        guard let id = currentDefaultInputID() else { return nil }
        return uid(forDevice: id)
    }

    func currentDefaultOutputUID() -> String? {
        guard let id = currentDefaultOutputID() else { return nil }
        return uid(forDevice: id)
    }

    func setLocked(uid: String?) {
        lockedUID = uid
        enforce()
    }

    func setLockEnabled(_ on: Bool) {
        lockEnabled = on
        if on { enforce() }
    }

    func setDefaultOutput(uid: String) {
        guard let id = deviceID(forUID: uid) else { return }
        setDefaultOutput(id)
    }

    // MARK: - Enforcement

    private func enforce() {
        guard lockEnabled, let want = lockedUID else { return }
        guard let id = deviceID(forUID: want) else { return }
        if currentDefaultInputID() != id {
            setDefaultInput(id)
        }
    }

    // MARK: - Device enumeration

    private func allDevices() -> [AudioDevice] {
        var size: UInt32 = 0
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size)
        guard status == noErr, size > 0 else { return [] }
        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        var ids = [AudioDeviceID](repeating: 0, count: count)
        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &ids)
        guard status == noErr else { return [] }
        return ids.compactMap { id -> AudioDevice? in
            guard let u = uid(forDevice: id), let n = name(forDevice: id) else { return nil }
            return AudioDevice(id: id, uid: u, name: n, transport: transport(forDevice: id))
        }
    }

    private func hasStreams(_ deviceID: AudioDeviceID, scope: AudioObjectPropertyScope) -> Bool {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &addr, 0, nil, &size) == noErr,
              size > 0 else { return false }
        let buf = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: 8)
        defer { buf.deallocate() }
        guard AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, buf) == noErr else {
            return false
        }
        let abl = buf.bindMemory(to: AudioBufferList.self, capacity: 1)
        let list = UnsafeMutableAudioBufferListPointer(abl)
        for b in list { if b.mNumberChannels > 0 { return true } }
        return false
    }

    private func isInput(deviceID: AudioDeviceID) -> Bool {
        hasStreams(deviceID, scope: kAudioDevicePropertyScopeInput)
    }

    private func isOutput(deviceID: AudioDeviceID) -> Bool {
        hasStreams(deviceID, scope: kAudioDevicePropertyScopeOutput)
    }

    private func uid(forDevice id: AudioDeviceID) -> String? {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var cfStr: CFString = "" as CFString
        var size = UInt32(MemoryLayout<CFString?>.size)
        let status = withUnsafeMutablePointer(to: &cfStr) { ptr -> OSStatus in
            ptr.withMemoryRebound(to: CFString?.self, capacity: 1) { p in
                AudioObjectGetPropertyData(id, &addr, 0, nil, &size, p)
            }
        }
        guard status == noErr else { return nil }
        return cfStr as String
    }

    private func name(forDevice id: AudioDeviceID) -> String? {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var cfStr: CFString = "" as CFString
        var size = UInt32(MemoryLayout<CFString?>.size)
        let status = withUnsafeMutablePointer(to: &cfStr) { ptr -> OSStatus in
            ptr.withMemoryRebound(to: CFString?.self, capacity: 1) { p in
                AudioObjectGetPropertyData(id, &addr, 0, nil, &size, p)
            }
        }
        guard status == noErr else { return nil }
        return cfStr as String
    }

    private func transport(forDevice id: AudioDeviceID) -> DeviceTransport {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &value)
        guard status == noErr else { return .other }
        switch value {
        case kAudioDeviceTransportTypeBuiltIn: return .builtIn
        case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE: return .bluetooth
        case kAudioDeviceTransportTypeUSB: return .usb
        case kAudioDeviceTransportTypeAggregate: return .aggregate
        case kAudioDeviceTransportTypeVirtual: return .virtual
        default: return .other
        }
    }

    private func deviceID(forUID targetUID: String) -> AudioDeviceID? {
        allDevices().first { $0.uid == targetUID }?.id
    }

    // MARK: - Defaults get/set

    private func currentDefaultInputID()  -> AudioDeviceID? { defaultDevice(.input) }
    private func currentDefaultOutputID() -> AudioDeviceID? { defaultDevice(.output) }

    private enum DefaultKind { case input, output }
    private func defaultDevice(_ kind: DefaultKind) -> AudioDeviceID? {
        var addr = AudioObjectPropertyAddress(
            mSelector: kind == .input
                ? kAudioHardwarePropertyDefaultInputDevice
                : kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var id: AudioDeviceID = 0
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &id)
        return status == noErr ? id : nil
    }

    private func setDefaultInput(_ id: AudioDeviceID)  { setDefault(id, kind: .input) }
    private func setDefaultOutput(_ id: AudioDeviceID) { setDefault(id, kind: .output) }

    private func setDefault(_ id: AudioDeviceID, kind: DefaultKind) {
        var addr = AudioObjectPropertyAddress(
            mSelector: kind == .input
                ? kAudioHardwarePropertyDefaultInputDevice
                : kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value = id
        let size = UInt32(MemoryLayout<AudioDeviceID>.size)
        AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, size, &value)
    }

    // MARK: - Listeners

    private func installListeners() {
        let selectors: [AudioObjectPropertySelector] = [
            kAudioHardwarePropertyDevices,
            kAudioHardwarePropertyDefaultInputDevice,
            kAudioHardwarePropertyDefaultOutputDevice
        ]
        for sel in selectors {
            var addr = AudioObjectPropertyAddress(
                mSelector: sel,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            AudioObjectAddPropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject), &addr, queue
            ) { [weak self] _, _ in
                guard let self = self else { return }
                self.queue.asyncAfter(deadline: .now() + 0.2) {
                    self.enforce()
                    DispatchQueue.main.async { self.onDevicesChanged?() }
                }
            }
        }
    }
}
