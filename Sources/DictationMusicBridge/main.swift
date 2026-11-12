import AppKit
import ApplicationServices
import OSLog
import ServiceManagement

private let logger = Logger(subsystem: "local.dictation-music-bridge", category: "playback")

final class DictationBridge: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let music = MusicControl()
    private var item: NSStatusItem?
    private var permissionItem: NSMenuItem?
    private var loginItem: NSMenuItem?
    private var observers: [NSObjectProtocol] = []
    private var timer: Timer?
    private var active = false
    private var pausedPID: pid_t?
    private var releaseAt: TimeInterval?
    private var silentSince: TimeInterval?
    private var lastStart: TimeInterval = 0
    private var now: TimeInterval { ProcessInfo.processInfo.systemUptime }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let center = DistributedNotificationCenter.default()
        for name in ["DictationIMNotificationWillStartListening", "DictationIMNotificationStartedListening",
                     "DictationIMNotificationStoppedListening", "DictationIMNotificationDidExitDictationMode"] {
            observers.append(center.addObserver(forName: .init(name), object: nil, queue: .main) { [weak self] _ in
                switch name {
                case "DictationIMNotificationWillStartListening", "DictationIMNotificationStartedListening":
                    self?.begin()
                case "DictationIMNotificationStoppedListening":
                    self?.scheduleEnd(after: 1.2)
                default:
                    self?.scheduleEnd(after: 0.35)
                }
            })
        }
        let status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        status.button?.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "听写音乐联动")
        status.button?.toolTip = "听写音乐联动"
        let menu = NSMenu()
        menu.delegate = self
        let title = NSMenuItem(title: "听写音乐联动 · 网易云音乐", action: nil, keyEquivalent: "")
        menu.addItem(title)
        permissionItem = add("辅助功能权限", #selector(requestAccess), to: menu)
        loginItem = add("登录时启动", #selector(toggleLogin), to: menu)
        menu.addItem(.separator())
        _ = add("退出听写音乐联动", #selector(quit), to: menu)
        status.menu = menu
        item = status

        let loginStatus = SMAppService.mainApp.status
        if CommandLine.arguments.contains("--register-login"), loginStatus == .notRegistered || loginStatus == .notFound {
            changeLogin(enable: true)
        }
        logger.notice("Bridge started. Accessibility granted: \(AXIsProcessTrusted())")
        if CommandLine.arguments.contains("--setup"), !AXIsProcessTrusted() { requestAccess() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        for observer in observers { DistributedNotificationCenter.default().removeObserver(observer) }
        finish()
    }

    func menuWillOpen(_ menu: NSMenu) {
        let authorized = AXIsProcessTrusted()
        permissionItem?.title = authorized ? "辅助功能：已授权" : "授予辅助功能权限…"
        permissionItem?.action = authorized ? nil : #selector(requestAccess)
        switch SMAppService.mainApp.status {
        case .enabled: loginItem?.state = .on; loginItem?.title = "登录时启动"
        case .requiresApproval: loginItem?.state = .mixed; loginItem?.title = "在系统设置中允许登录时启动…"
        default: loginItem?.state = .off; loginItem?.title = "登录时启动"
        }
    }

    private func add(_ title: String, _ action: Selector, to menu: NSMenu) -> NSMenuItem {
        let entry = NSMenuItem(title: title, action: action, keyEquivalent: "")
        entry.target = self
        menu.addItem(entry)
        return entry
    }

    @objc private func requestAccess() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        guard !AXIsProcessTrustedWithOptions(options) else { return }
        if let settings = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(settings)
        }
    }

    @objc private func toggleLogin() {
        let status = SMAppService.mainApp.status
        if status == .requiresApproval { SMAppService.openSystemSettingsLoginItems(); return }
        changeLogin(enable: status != .enabled)
    }

    private func changeLogin(enable: Bool) {
        do {
            if enable { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            logger.notice("Login item status: \(SMAppService.mainApp.status.rawValue)")
        } catch {
            logger.error("Login item could not be updated: \(error.localizedDescription, privacy: .public)")
        }
    }

    @objc private func quit() { NSApp.terminate(nil) }

    private func begin() {
        lastStart = now
        releaseAt = nil
        silentSince = nil
        guard !active else { return }
        active = true
        logger.notice("Dictation started")
        if let pid = music.currentPID, music.changePlayback(of: pid, from: .playing) {
            pausedPID = pid
            logger.notice("Pause sent to NetEase Music")
        }
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in self?.checkSession() }
    }

    private func scheduleEnd(after delay: TimeInterval) {
        guard active else { return }
        let proposed = now + delay
        releaseAt = min(releaseAt ?? proposed, proposed)
    }

    private func checkSession() {
        let instant = now
        if let releaseAt, instant >= releaseAt { finish(); return }
        if let pid = pausedPID, instant - lastStart > 0.8, music.state(of: pid) == .playing {
            // Playback has already resumed (or the pause had no effect).
            pausedPID = nil
        }
        // If the dictation service exits before sending an end notice, recover after
        // CoreSpeech has released the mic. We never pause from the mic signal alone.
        if instant - lastStart > 2.5, let usingInput = AudioActivity.isCoreSpeechUsingInput() {
            if usingInput {
                silentSince = nil
            } else {
                silentSince = silentSince ?? instant
                if instant - (silentSince ?? instant) > 2 { finish() }
            }
        }
    }

    private func finish() {
        timer?.invalidate()
        timer = nil
        guard active else { return }
        active = false
        releaseAt = nil
        if let pid = pausedPID, music.changePlayback(of: pid, from: .paused) {
            logger.notice("Resume sent to NetEase Music")
        }
        pausedPID = nil
        logger.notice("Dictation ended")
    }
}

if CommandLine.arguments.contains("--status") {
    print("Accessibility: \(AXIsProcessTrusted()); NetEase Music: \(MusicControl().state())")
} else {
    let app = NSApplication.shared
    let delegate = DictationBridge()
    app.setActivationPolicy(.accessory)
    app.delegate = delegate
    app.run()
}
