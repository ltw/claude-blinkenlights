import AppKit
import Foundation

// State file layout: ~/.claude/state/sessions/<session_id>.json
// Each file: { session_id, cwd, pid, state: "active"|"idle", last_activity, started }
//
// "active"  = user prompt submitted, no Stop/SessionEnd yet, updated within ACTIVE_WINDOW.
// "idle"    = anything else. Stale files (pid gone, or old) are pruned.

let ACTIVE_WINDOW: TimeInterval = 600   // forgive up to 10m between hook events in one turn
let POLL_INTERVAL: TimeInterval = 1.0

struct SessionState {
    var sessionID: String
    var cwd: String
    var pid: Int?
    var state: String
    var lastActivity: TimeInterval
    var age: TimeInterval { Date().timeIntervalSince1970 - lastActivity }
}

func stateDir() -> URL {
    FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/state/sessions", isDirectory: true)
}

func pidAlive(_ pid: Int) -> Bool {
    kill(pid_t(pid), 0) == 0 || errno == EPERM
}

func loadActiveSessions() -> [SessionState] {
    let dir = stateDir()
    let fm = FileManager.default
    guard let items = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else {
        return []
    }
    var out: [SessionState] = []
    for url in items where url.pathExtension == "json" {
        guard let data = try? Data(contentsOf: url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
        let s = SessionState(
            sessionID: obj["session_id"] as? String ?? url.deletingPathExtension().lastPathComponent,
            cwd: obj["cwd"] as? String ?? "",
            pid: obj["pid"] as? Int,
            state: obj["state"] as? String ?? "idle",
            lastActivity: (obj["last_activity"] as? NSNumber)?.doubleValue ?? 0
        )
        if let pid = s.pid, !pidAlive(pid) {
            try? fm.removeItem(at: url); continue
        }
        if s.age > ACTIVE_WINDOW {
            try? fm.removeItem(at: url); continue
        }
        if s.state == "active" { out.append(s) }
    }
    return out.sorted { $0.lastActivity > $1.lastActivity }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var timer: Timer?
    var menu: NSMenu!

    func applicationDidFinishLaunching(_: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        menu = NSMenu()
        statusItem.menu = menu
        tick()
        timer = Timer.scheduledTimer(withTimeInterval: POLL_INTERVAL, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func tick() {
        let active = loadActiveSessions()
        render(active: active)
    }

    func render(active: [SessionState]) {
        guard let button = statusItem.button else { return }
        let isActive = !active.isEmpty

        let cfg = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        let symbol = isActive ? "circle.fill" : "circle"
        let tint: NSColor = isActive ? .systemGreen : .tertiaryLabelColor
        let img = NSImage(systemSymbolName: symbol, accessibilityDescription: isActive ? "Claude active" : "Claude idle")?
            .withSymbolConfiguration(cfg)
        button.image = img?.tinted(with: tint)
        button.imagePosition = .imageLeft
        button.title = isActive ? " \(active.count)" : ""

        rebuildMenu(active: active)
    }

    func rebuildMenu(active: [SessionState]) {
        menu.removeAllItems()
        let header = active.isEmpty
            ? "Idle — kick off a prompt"
            : "Active: \(active.count) session\(active.count == 1 ? "" : "s")"
        let h = NSMenuItem(title: header, action: nil, keyEquivalent: "")
        h.isEnabled = false
        menu.addItem(h)
        menu.addItem(.separator())

        if active.isEmpty {
            let i = NSMenuItem(title: "No sessions are responding to a prompt", action: nil, keyEquivalent: "")
            i.isEnabled = false
            menu.addItem(i)
        } else {
            for s in active {
                let cwd = URL(fileURLWithPath: s.cwd).lastPathComponent
                let title = "\(cwd) · \(formatAge(s.age))"
                let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
                item.isEnabled = false
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Open state dir", action: #selector(openStateDir), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        for i in menu.items where i.action != nil { i.target = self }
    }

    func formatAge(_ age: TimeInterval) -> String {
        if age < 2 { return "now" }
        if age < 60 { return "\(Int(age))s ago" }
        if age < 3600 { return "\(Int(age/60))m ago" }
        return "\(Int(age/3600))h ago"
    }

    @objc func openStateDir() { NSWorkspace.shared.open(stateDir()) }
    @objc func quit() { NSApp.terminate(nil) }
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
