import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let audio = AudioController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "mic.fill",
                accessibilityDescription: "MicLock"
            )
        }
        rebuildMenu()
        audio.onDevicesChanged = { [weak self] in self?.rebuildMenu() }
    }

    @objc private func selectDevice(_ sender: NSMenuItem) {
        guard let uid = sender.representedObject as? String else { return }
        if audio.lockedUID == uid {
            audio.setLocked(uid: nil)
        } else {
            audio.setLocked(uid: uid)
        }
        rebuildMenu()
    }

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
        rebuildMenu()
    }

    @objc private func openSoundSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Sound-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        let credits = NSAttributedString(
            string: "Locks your macOS default input device so connecting Bluetooth or USB audio never hijacks your microphone.\n\nMade by Sergey · 2026",
            attributes: [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: NSColor.labelColor
            ]
        )
        NSApp.orderFrontStandardAboutPanel(options: [
            .credits: credits,
            .applicationName: "MicLock",
            .applicationVersion: "1.0.0",
            .version: "1"
        ])
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func rebuildMenu() {
        let menu = NSMenu()

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
                let item = NSMenuItem(
                    title: d.name,
                    action: #selector(selectDevice(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = d.uid
                if audio.lockedUID == d.uid { item.state = .on }
                if d.uid == currentDefault {
                    item.title = "\(d.name)  ◆"
                }
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

        self.statusItem.menu = menu
    }
}
