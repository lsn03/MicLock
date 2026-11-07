import CoreAudio
import Foundation

struct AudioDevice: Equatable {
    let id: AudioDeviceID
    let uid: String
    let name: String
}

final class AudioController {
    private let defaultsKey = "lockedInputUID"
    private let queue = DispatchQueue(label: "MicLock.audio")

    var onDevicesChanged: (() -> Void)?

    private(set) var lockedUID: String? {
        didSet { UserDefaults.standard.set(lockedUID, forKey: defaultsKey) }
    }

    init() {
        self.lockedUID = UserDefaults.standard.string(forKey: defaultsKey)
        installListeners()
        // Enforce once at launch in case current default differs.
        enforce()
    }

    // MARK: - Public

    func inputDevices() -> [AudioDevice] {
        allDevices().filter { isInput(deviceID: $0.id) }
    }

    func currentDefaultInputUID() -> String? {
        guard let id = currentDefaultInputID() else { return nil }
        return uid(forDevice: id)
    }

    func setLocked(uid: String?) {
        lockedUID = uid
        enforce()
    }

    // MARK: - Enforcement

    private func enforce() {
        guard let want = lockedUID else { return }
        guard let id = deviceID(forUID: want) else { return }
        if currentDefaultInputID() != id {
            setDefaultInput(id)
        }
    }

    // MARK: - CoreAudio helpers

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
            return AudioDevice(id: id, uid: u, name: n)
        }
    }

    private func isInput(deviceID: AudioDeviceID) -> Bool {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeInput,
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

    private func deviceID(forUID targetUID: String) -> AudioDeviceID? {
        allDevices().first { $0.uid == targetUID }?.id
    }

    private func currentDefaultInputID() -> AudioDeviceID? {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var id: AudioDeviceID = 0
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &id)
        return status == noErr ? id : nil
    }

    private func setDefaultInput(_ id: AudioDeviceID) {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
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
            kAudioHardwarePropertyDefaultInputDevice
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
                // Give the system a moment to settle before re-asserting.
                self.queue.asyncAfter(deadline: .now() + 0.2) {
                    self.enforce()
                    DispatchQueue.main.async { self.onDevicesChanged?() }
                }
            }
        }
    }
}
