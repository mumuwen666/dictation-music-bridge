import CoreAudio
import Darwin

struct AudioActivity {
    static func isCoreSpeechUsingInput() -> Bool? {
        let system = AudioObjectID(kAudioObjectSystemObject)
        var address = property(kAudioHardwarePropertyProcessObjectList)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr else { return nil }
        guard size > 0 else { return false }
        let width = MemoryLayout<AudioObjectID>.stride
        guard Int(size).isMultiple(of: width) else { return nil }
        var objects = [AudioObjectID](repeating: 0, count: Int(size) / width)
        let status = objects.withUnsafeMutableBytes { bytes in
            AudioObjectGetPropertyData(system, &address, 0, nil, &size, bytes.baseAddress!)
        }
        guard status == noErr else { return nil }
        for object in objects.prefix(Int(size) / width) {
            var running: UInt32 = 0
            guard read(object, kAudioProcessPropertyIsRunningInput, into: &running), running != 0 else { continue }
            var rawID: Unmanaged<CFString>?
            guard read(object, kAudioProcessPropertyBundleID, into: &rawID),
                  rawID?.takeRetainedValue() as String? == "com.apple.CoreSpeech" else { continue }
            var pid: pid_t = 0
            guard read(object, kAudioProcessPropertyPID, into: &pid), pid > 0 else { return nil }
            var path = [CChar](repeating: 0, count: Int(MAXPATHLEN) * 4)
            guard proc_pidpath(pid, &path, UInt32(path.count)) > 0 else { return nil }
            let executable = path.withUnsafeBufferPointer { String(validatingCString: $0.baseAddress!) }
            if executable?.hasSuffix("/corespeechd") == true { return true }
        }
        return false
    }

    private static func property(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    }

    private static func read<T>(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector, into value: inout T) -> Bool {
        var address = property(selector)
        var size = UInt32(MemoryLayout<T>.size)
        return withUnsafeMutableBytes(of: &value) { bytes in
            AudioObjectGetPropertyData(object, &address, 0, nil, &size, bytes.baseAddress!) == noErr
        }
    }
}
