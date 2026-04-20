import XCTest
@testable import ClaudeBlinkenlightsCore

final class SessionReaderTests: XCTestCase {
    var tmp: URL!

    override func setUpWithError() throws {
        tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("cbl-sessions-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tmp)
    }

    private func writeSession(_ name: String, _ obj: [String: Any]) throws {
        let data = try JSONSerialization.data(withJSONObject: obj)
        try data.write(to: tmp.appendingPathComponent("\(name).json"))
    }

    func testParsesActiveAndIdle() throws {
        let now = Date().timeIntervalSince1970
        try writeSession("a", [
            "session_id": "a", "cwd": "/tmp/one",
            "state": "active", "pid": 999_999, "last_activity": now,
        ])
        try writeSession("b", [
            "session_id": "b", "cwd": "/tmp/two",
            "state": "idle",   "pid": 999_999, "last_activity": now,
        ])
        let records = readSessions(from: tmp)
        XCTAssertEqual(records.count, 2)

        let active = activeSessions(from: records)
        XCTAssertEqual(active.count, 1)
        XCTAssertEqual(active.first?.cwd, "/tmp/one")
    }

    func testIsStaleByAge() {
        let record = SessionRecord(
            url: tmp.appendingPathComponent("x.json"),
            state: "active", cwd: "/", lastActivity: 0, pid: nil)
        XCTAssertTrue(record.isStale(now: activeWindow + 1))
        XCTAssertFalse(record.isStale(now: activeWindow - 1))
    }

    func testIsStaleByDeadPid() {
        let record = SessionRecord(
            url: tmp.appendingPathComponent("x.json"),
            state: "active", cwd: "/",
            lastActivity: Date().timeIntervalSince1970, pid: 424242)
        XCTAssertTrue(record.isStale(
            now: Date().timeIntervalSince1970,
            pidAlive: { _ in false }))
        XCTAssertFalse(record.isStale(
            now: Date().timeIntervalSince1970,
            pidAlive: { _ in true }))
    }

    func testMalformedFileIgnored() throws {
        try "not json".write(to: tmp.appendingPathComponent("bad.json"),
                             atomically: true, encoding: .utf8)
        XCTAssertEqual(readSessions(from: tmp).count, 0)
    }
}
