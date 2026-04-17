import AppKit
import Foundation

private let activeWindow: TimeInterval = 600
private let pollInterval: TimeInterval = 1.0

private struct Session {
    let cwd: String
    let lastActivity: TimeInterval
    var age: TimeInterval { Date().timeIntervalSince1970 - lastActivity }
}

private func sessionsDir() -> URL {
    FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/state/sessions", isDirectory: true)
}

private func pidAlive(_ pid: Int) -> Bool {
    kill(pid_t(pid), 0) == 0 || errno == EPERM
}

private func loadActiveSessions() -> [Session] {
    let fm = FileManager.default
    let urls = (try? fm.contentsOfDirectory(at: sessionsDir(), includingPropertiesForKeys: nil)) ?? []
    return urls
        .filter { $0.pathExtension == "json" }
        .compactMap { url -> Session? in
            guard let data = try? Data(contentsOf: url),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { return nil }

            let lastActivity = (obj["last_activity"] as? NSNumber)?.doubleValue ?? 0
            let pid = obj["pid"] as? Int
            let stale = (pid.map { !pidAlive($0) } ?? false)
                || Date().timeIntervalSince1970 - lastActivity > activeWindow
            if stale {
                try? fm.removeItem(at: url)
                return nil
            }
            guard (obj["state"] as? String) == "active" else { return nil }
            return Session(cwd: obj["cwd"] as? String ?? "", lastActivity: lastActivity)
        }
        .sorted { $0.lastActivity > $1.lastActivity }
}

private func formatAge(_ age: TimeInterval) -> String {
    switch age {
    case ..<2:    return "now"
    case ..<60:   return "\(Int(age))s ago"
    case ..<3600: return "\(Int(age / 60))m ago"
    default:      return "\(Int(age / 3600))h ago"
    }
}

private func statusImage(active: Bool) -> NSImage? {
    let cfg = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
    let name = active ? "circle.fill" : "circle"
    let tint: NSColor = active ? .systemGreen : .tertiaryLabelColor
    let label = active ? "Claude active" : "Claude idle"
    return NSImage(systemSymbolName: name, accessibilityDescription: label)?
        .withSymbolConfiguration(cfg)?
        .tinted(with: tint)
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private var timer: Timer?
    private lazy var activeImage = statusImage(active: true)
    private lazy var idleImage = statusImage(active: false)

    func applicationDidFinishLaunching(_: Notification) {
        statusItem.menu = menu
        tick()
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func tick() {
        let sessions = loadActiveSessions()
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
        menu.addItem(action("Quit", #selector(quit), key: "q"))
    }

    private func headerText(_ sessions: [Session]) -> String {
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

    @objc private func openStateDir() { NSWorkspace.shared.open(sessionsDir()) }
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
