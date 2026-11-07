import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private let audio = AudioController()
    private var autoCloseTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            if let url = Bundle.main.url(forResource: "MicLockTemplate", withExtension: "pdf"),
               let img = NSImage(contentsOf: url) {
                img.size = NSSize(width: 18, height: 18)
                img.isTemplate = true
                button.image = img
            } else {
                button.image = NSImage(
                    systemSymbolName: "mic.fill",
                    accessibilityDescription: "MicLock"
                )
            }
        }
        menu.delegate = self
        statusItem.menu = menu
        rebuildMenu()
        audio.onDevicesChanged = { [weak self] in self?.rebuildMenu() }
    }

    // MARK: - NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuildMenu()
    }

    func menuWillOpen(_ menu: NSMenu) {
        restartAutoCloseTimer()
    }

    func menuDidClose(_ menu: NSMenu) {
        autoCloseTimer?.invalidate()
        autoCloseTimer = nil
    }

    // MARK: - Device click (from DeviceRowView)

    private func handleDeviceClick(uid: String) {
        audio.setLocked(uid: uid)
        if Settings.shared.keepMenuOpenAfterSelection {
            restartAutoCloseTimer()
            DispatchQueue.main.async { [weak self] in self?.rebuildMenu() }
        } else {
            menu.cancelTracking()
        }
    }

    // MARK: - Actions

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            NSLog("MicLock: launch-at-login toggle failed: \(error)")
        }
    }

    @objc private func openSoundSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Sound-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        let credits = NSAttributedString(
            string: "Locks your macOS default input device so connecting Bluetooth or USB audio never hijacks your microphone.\n\nMade by Lvov Sergei · 2026",
            attributes: [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: NSColor.labelColor
            ]
        )
        NSApp.orderFrontStandardAboutPanel(options: [
            .credits: credits,
            .applicationName: "MicLock",
            .applicationVersion: "1.0.1",
            .version: "2"
        ])
    }

    @objc private func quit() { NSApp.terminate(nil) }

    // MARK: - Auto-close

    private func restartAutoCloseTimer() {
        autoCloseTimer?.invalidate()
        let seconds = Settings.shared.autoCloseSeconds
        autoCloseTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in
            self?.menu.cancelTracking()
        }
        if let t = autoCloseTimer {
            RunLoop.current.add(t, forMode: .eventTracking)
        }
    }

    // MARK: - Menu

    private func rebuildMenu() {
        menu.removeAllItems()

        let header = NSMenuItem(title: "Lock input device:", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        let devices = audio.inputDevices()
        let currentDefault = audio.currentDefaultInputUID()

        if devices.isEmpty {
            let empty = NSMenuItem(title: "No input devices", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            for d in devices {
                let row = DeviceRowView(
                    uid: d.uid,
                    name: d.name,
                    checked: audio.lockedUID == d.uid,
                    isActiveDefault: d.uid == currentDefault
                ) { [weak self] uid in
                    self?.handleDeviceClick(uid: uid)
                }
                let item = NSMenuItem()
                item.view = row
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())

        let status: String
        if let locked = audio.lockedUID,
           let name = devices.first(where: { $0.uid == locked })?.name {
            status = "Locked: \(name)"
        } else if audio.lockedUID != nil {
            status = "Locked: (device unavailable)"
        } else {
            status = "Not locked"
        }
        let statusLine = NSMenuItem(title: status, action: nil, keyEquivalent: "")
        statusLine.isEnabled = false
        menu.addItem(statusLine)

        menu.addItem(.separator())

        let launchItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin(_:)),
            keyEquivalent: ""
        )
        launchItem.target = self
        launchItem.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
        menu.addItem(launchItem)

        let soundItem = NSMenuItem(
            title: "Sound Settings…",
            action: #selector(openSoundSettings),
            keyEquivalent: ""
        )
        soundItem.target = self
        menu.addItem(soundItem)

        // Preferences submenu
        let prefsItem = NSMenuItem(title: "Preferences", action: nil, keyEquivalent: "")
        let prefs = NSMenu()
        let keepOpenItem = NSMenuItem()
        keepOpenItem.view = CheckboxRowView(
            label: "Keep menu open after selection",
            checked: Settings.shared.keepMenuOpenAfterSelection
        ) { value in
            Settings.shared.keepMenuOpenAfterSelection = value
        }
        prefs.addItem(keepOpenItem)
        prefsItem.submenu = prefs
        menu.addItem(prefsItem)

        menu.addItem(.separator())

        let aboutItem = NSMenuItem(
            title: "About MicLock",
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)

        let quitItem = NSMenuItem(title: "Quit MicLock", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }
}
