import Foundation

public let activeWindow: TimeInterval = 600

public struct SessionRecord {
    public let url: URL
    public let state: String
    public let cwd: String
    public let lastActivity: TimeInterval
    public let pid: Int?

    public init(url: URL, state: String, cwd: String, lastActivity: TimeInterval, pid: Int?) {
        self.url = url
        self.state = state
        self.cwd = cwd
        self.lastActivity = lastActivity
        self.pid = pid
    }

    public func isStale(now: TimeInterval = Date().timeIntervalSince1970,
                       pidAlive: (Int) -> Bool = defaultPidAlive) -> Bool {
        if let pid, !pidAlive(pid) { return true }
        return now - lastActivity > activeWindow
    }
}

public struct ActiveSession {
    public let cwd: String
    public let lastActivity: TimeInterval
    public var age: TimeInterval { Date().timeIntervalSince1970 - lastActivity }
}

public func defaultSessionsDir() -> URL {
    FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/state/sessions", isDirectory: true)
}

public func defaultPidAlive(_ pid: Int) -> Bool {
    kill(pid_t(pid), 0) == 0 || errno == EPERM
}

public func parseSessionRecord(at url: URL) -> SessionRecord? {
    guard let data = try? Data(contentsOf: url),
          let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else { return nil }
    return SessionRecord(
        url: url,
        state: obj["state"] as? String ?? "idle",
        cwd: obj["cwd"] as? String ?? "",
        lastActivity: (obj["last_activity"] as? NSNumber)?.doubleValue ?? 0,
        pid: obj["pid"] as? Int)
}

public func readSessions(from dir: URL = defaultSessionsDir()) -> [SessionRecord] {
    let urls = (try? FileManager.default.contentsOfDirectory(
        at: dir, includingPropertiesForKeys: nil)) ?? []
    return urls.filter { $0.pathExtension == "json" }.compactMap(parseSessionRecord)
}

public func pruneStale(_ records: [SessionRecord]) {
    for r in records where r.isStale() {
        try? FileManager.default.removeItem(at: r.url)
    }
}

public func activeSessions(from records: [SessionRecord]) -> [ActiveSession] {
    records
        .filter { !$0.isStale() && $0.state == "active" }
        .map { ActiveSession(cwd: $0.cwd, lastActivity: $0.lastActivity) }
        .sorted { $0.lastActivity > $1.lastActivity }
}
