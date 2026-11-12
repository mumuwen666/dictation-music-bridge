import AppKit
import ApplicationServices

enum MusicState: Equatable {
    case playing
    case paused
    case unavailable
}

struct MusicControl {
    private static let bundleID = "com.netease.163music"
    private static let controlMenus: Set<String> = ["控制", "播放控制", "Controls", "Control"]
    private static let pauseItems: Set<String> = ["暂停", "暂停播放", "暫停", "暫停播放", "Pause", "Pause Playback"]
    private static let playItems: Set<String> = ["播放", "继续播放", "繼續播放", "Play", "Resume", "Play Playback"]

    func state() -> MusicState {
        guard let pid = currentPID else { return .unavailable }
        return state(of: pid)
    }

    var currentPID: pid_t? {
        NSRunningApplication.runningApplications(withBundleIdentifier: Self.bundleID).first?.processIdentifier
    }

    func state(of pid: pid_t) -> MusicState {
        control(of: pid)?.state ?? .unavailable
    }

    func changePlayback(of pid: pid_t, from expected: MusicState) -> Bool {
        guard expected != .unavailable, let control = control(of: pid), control.state == expected else { return false }
        return AXUIElementPerformAction(control.element, kAXPressAction as CFString) == .success
    }

    private func control(of pid: pid_t) -> (element: AXUIElement, state: MusicState)? {
        guard AXIsProcessTrusted(), currentPID == pid else { return nil }

        let application = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(application, 0.3)
        if let control = menuControl(in: application) { return control }

        // Some versions load the Controls menu lazily until an accessibility client connects.
        AXUIElementSetAttributeValue(application, "AXManualAccessibility" as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(application, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)
        return menuControl(in: application)
    }

    private func menuControl(in application: AXUIElement) -> (element: AXUIElement, state: MusicState)? {
        guard let value = attribute(kAXMenuBarAttribute, of: application),
              CFGetTypeID(value) == AXUIElementGetTypeID()
        else { return nil }

        let menuBar = value as! AXUIElement
        let controls = children(of: menuBar).filter { Self.controlMenus.contains(title(of: $0)) }
        let playbackItems = controls.flatMap { children(of: $0) }.flatMap { children(of: $0) }
        var result: (element: AXUIElement, state: MusicState)?
        for item in playbackItems where attribute(kAXEnabledAttribute, of: item) as? Bool == true {
            let label = title(of: item)
            let state: MusicState
            if Self.pauseItems.contains(label) {
                state = .playing
            } else if Self.playItems.contains(label) {
                state = .paused
            } else {
                continue
            }
            // A toggle with a generic label or multiple enabled matches is ambiguous.
            guard result == nil else { return nil }
            result = (item, state)
        }
        return result
    }

    private func title(of element: AXUIElement) -> String {
        (attribute(kAXTitleAttribute, of: element) as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func children(of element: AXUIElement) -> [AXUIElement] {
        attribute(kAXChildrenAttribute, of: element) as? [AXUIElement] ?? []
    }

    private func attribute(_ name: String, of element: AXUIElement) -> CFTypeRef? {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
    }
}
