import Foundation

public struct HooksInstaller {
    public let settingsPath: URL
    public let hooksDir: URL

    public static let eventScripts: KeyValuePairs<String, String> = [
        "UserPromptSubmit": "user-prompt-submit.sh",
        "Stop":             "stop.sh",
        "SessionEnd":       "session-end.sh",
    ]
    public static let allScripts: [String] =
        eventScripts.map(\.value) + ["_update.sh"]

    public init(settingsPath: URL? = nil, hooksDir: URL? = nil) {
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.settingsPath = settingsPath
            ?? home.appendingPathComponent(".claude/settings.json")
        self.hooksDir = hooksDir
            ?? home.appendingPathComponent(".claude/hooks/claude-blinkenlights")
    }

    public var isInstalled: Bool {
        let fm = FileManager.default
        let allScriptsPresent = Self.allScripts.allSatisfy {
            fm.fileExists(atPath: hooksDir.appendingPathComponent($0).path)
        }
        guard allScriptsPresent,
              let hooks = loadSettings()["hooks"] as? [String: Any]
        else { return false }
        return Self.eventScripts.allSatisfy { event, _ in
            ((hooks[event] as? [[String: Any]]) ?? []).contains(where: blockHasOurs)
        }
    }

    public func install(from source: URL) throws {
        try copyScripts(from: source)
        try updateSettings { hooks in insertOurs(into: &hooks) }
    }

    public func uninstall() throws {
        if FileManager.default.fileExists(atPath: settingsPath.path) {
            try updateSettings { _ in }
        }
        try? FileManager.default.removeItem(at: hooksDir)
    }

    // MARK: - Settings surgery

    /// Strips our entries, runs `transform` on the remaining hooks, writes back.
    /// Install = transform inserts ours. Uninstall = transform is a no-op.
    func updateSettings(_ transform: (inout [String: Any]) -> Void) throws {
        var config = loadSettings()
        var hooks = (config["hooks"] as? [String: Any]) ?? [:]
        stripOurs(from: &hooks)
        transform(&hooks)
        if hooks.isEmpty { config.removeValue(forKey: "hooks") }
        else             { config["hooks"] = hooks }
        try writeSettings(config)
    }

    private func stripOurs(from hooks: inout [String: Any]) {
        for (event, raw) in hooks {
            guard var blocks = raw as? [[String: Any]] else { continue }
            for i in blocks.indices {
                let handlers = (blocks[i]["hooks"] as? [[String: Any]]) ?? []
                blocks[i]["hooks"] = handlers.filter { !isOurs($0) }
            }
            blocks.removeAll { (($0["hooks"] as? [[String: Any]])?.isEmpty ?? true) }
            if blocks.isEmpty { hooks.removeValue(forKey: event) }
            else              { hooks[event] = blocks }
        }
    }

    private func insertOurs(into hooks: inout [String: Any]) {
        for (event, script) in Self.eventScripts {
            var blocks = (hooks[event] as? [[String: Any]]) ?? []
            let i = blocks.firstIndex { ($0["matcher"] as? String) ?? "" == "" } ?? {
                blocks.append(["matcher": "", "hooks": [[String: Any]]()])
                return blocks.count - 1
            }()
            var handlers = (blocks[i]["hooks"] as? [[String: Any]]) ?? []
            handlers.append([
                "type": "command",
                "command": "bash \(hooksDir.path)/\(script)",
            ])
            blocks[i]["hooks"] = handlers
            hooks[event] = blocks
        }
    }

    // MARK: - Filesystem primitives

    private func copyScripts(from source: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: hooksDir, withIntermediateDirectories: true)
        for script in Self.allScripts {
            let dst = hooksDir.appendingPathComponent(script)
            try? fm.removeItem(at: dst)
            try fm.copyItem(at: source.appendingPathComponent(script), to: dst)
            try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: dst.path)
        }
    }

    private func loadSettings() -> [String: Any] {
        guard let data = try? Data(contentsOf: settingsPath),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [:] }
        return obj
    }

    private func writeSettings(_ config: [String: Any]) throws {
        try FileManager.default.createDirectory(
            at: settingsPath.deletingLastPathComponent(),
            withIntermediateDirectories: true)
        let data = try JSONSerialization.data(
            withJSONObject: config,
            options: [.prettyPrinted, .sortedKeys])
        try (data + Data([0x0a])).write(to: settingsPath, options: .atomic)
    }

    private func isOurs(_ handler: [String: Any]) -> Bool {
        (handler["command"] as? String)?.contains(hooksDir.path) ?? false
    }

    private func blockHasOurs(_ block: [String: Any]) -> Bool {
        ((block["hooks"] as? [[String: Any]]) ?? []).contains(where: isOurs)
    }
}

