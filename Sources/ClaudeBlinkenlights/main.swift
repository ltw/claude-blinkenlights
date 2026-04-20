import AppKit
import ClaudeBlinkenlightsCore
import Foundation
import ServiceManagement

private let pollInterval: TimeInterval = 1.0

private func statusImage(active: Bool) -> NSImage? {
    let cfg = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
    let name = active ? "circle.fill" : "circle"
    let tint: NSColor = active ? .systemGreen : .tertiaryLabelColor
    let label = active ? "Claude active" : "Claude idle"
    return NSImage(systemSymbolName: name, accessibilityDescription: label)?
        .withSymbolConfiguration(cfg)?
        .tinted(with: tint)
}

private func bundledHooksDir() -> URL? {
    Bundle.main.resourceURL?.appendingPathComponent("hooks", isDirectory: true)
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private var timer: Timer?
    private lazy var activeImage = statusImage(active: true)
    private lazy var idleImage = statusImage(active: false)
    private let installer = HooksInstaller()

    func applicationDidFinishLaunching(_: Notification) {
        statusItem.menu = menu
        firstRunInstallIfNeeded()
        tick()
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func firstRunInstallIfNeeded() {
        guard !installer.isInstalled, let source = bundledHooksDir() else { return }
        do { try installer.install(from: source) }
        catch { NSLog("claude-blinkenlights: first-run install failed: \(error)") }
    }

    private func tick() {
        let records = readSessions()
        pruneStale(records)
        let sessions = activeSessions(from: records)
        let isActive = !sessions.isEmpty

        if let button = statusItem.button {
            button.image = isActive ? activeImage : idleImage
            button.imagePosition = .imageLeft
            button.title = isActive ? " \(sessions.count)" : ""
        }

        menu.removeAllItems()
        menu.addItem(disabled(headerText(sessions)))
        menu.addItem(.separator())
        if sessions.isEmpty {
            menu.addItem(disabled("No sessions are responding to a prompt"))
        } else {
            for s in sessions {
                let name = URL(fileURLWithPath: s.cwd).lastPathComponent
                menu.addItem(disabled("\(name) · \(formatAge(s.age))"))
            }
        }
        menu.addItem(.separator())
        menu.addItem(action("Open state dir", #selector(openStateDir)))
        menu.addItem(openAtLoginItem())
        menu.addItem(.separator())
        menu.addItem(action("Reinstall Claude hooks", #selector(reinstallHooks)))
        menu.addItem(action("Remove Claude hooks", #selector(removeHooks)))
        menu.addItem(.separator())
        menu.addItem(action("Quit", #selector(quit), key: "q"))
    }

    private func headerText(_ sessions: [ActiveSession]) -> String {
        sessions.isEmpty
            ? "Idle — kick off a prompt"
            : "Active: \(sessions.count) session\(sessions.count == 1 ? "" : "s")"
    }

    private func disabled(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func action(_ title: String, _ selector: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: key)
        item.target = self
        return item
    }

    private func openAtLoginItem() -> NSMenuItem {
        let item = action("Open at Login", #selector(toggleOpenAtLogin))
        item.state = SMAppService.mainApp.status == .enabled ? .on : .off
        return item
    }

    @objc private func openStateDir() { NSWorkspace.shared.open(defaultSessionsDir()) }

    @objc private func toggleOpenAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("claude-blinkenlights: open-at-login toggle failed: \(error)")
        }
    }

    @objc private func reinstallHooks() {
        guard let source = bundledHooksDir() else { return }
        do { try installer.install(from: source) }
        catch { presentError("Reinstall failed", error) }
    }

    @objc private func removeHooks() {
        let alert = NSAlert()
        alert.messageText = "Remove Claude hooks?"
        alert.informativeText = "The menu bar app will keep running until you quit it."
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        do { try installer.uninstall() }
        catch { presentError("Remove failed", error) }
    }

    private func presentError(_ title: String, _ error: Error) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = "\(error)"
        alert.runModal()
    }

    @objc private func quit() { NSApp.terminate(nil) }
}

extension NSImage {
    func tinted(with color: NSColor) -> NSImage {
        let img = self.copy() as! NSImage
        img.lockFocus()
        color.set()
        NSRect(origin: .zero, size: img.size).fill(using: .sourceAtop)
        img.unlockFocus()
        img.isTemplate = false
        return img
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
