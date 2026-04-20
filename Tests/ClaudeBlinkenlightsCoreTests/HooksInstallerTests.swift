import XCTest
@testable import ClaudeBlinkenlightsCore

final class HooksInstallerTests: XCTestCase {
    var tmp: URL!
    var installer: HooksInstaller!
    var source: URL!

    override func setUpWithError() throws {
        tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("cbl-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)

        let settings = tmp.appendingPathComponent("settings.json")
        let hooksDir = tmp.appendingPathComponent("hooks/claude-blinkenlights")
        installer = HooksInstaller(settingsPath: settings, hooksDir: hooksDir)

        source = tmp.appendingPathComponent("source-hooks")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        for name in HooksInstaller.allScripts {
            try "#!/usr/bin/env bash\n".write(
                to: source.appendingPathComponent(name), atomically: true, encoding: .utf8)
        }
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tmp)
    }

    private func readJSON() throws -> [String: Any] {
        let data = try Data(contentsOf: installer.settingsPath)
        return try JSONSerialization.jsonObject(with: data) as! [String: Any]
    }

    private func writeJSON(_ obj: [String: Any]) throws {
        let data = try JSONSerialization.data(withJSONObject: obj, options: .prettyPrinted)
        try data.write(to: installer.settingsPath)
    }

    func testInstallFromEmpty() throws {
        try installer.install(from: source)
        XCTAssertTrue(installer.isInstalled)
        let hooks = try readJSON()["hooks"] as! [String: Any]
        for (event, _) in HooksInstaller.eventScripts {
            XCTAssertNotNil(hooks[event], "missing entry for \(event)")
        }
    }

    func testInstallIsIdempotent() throws {
        try installer.install(from: source)
        let first = try String(contentsOf: installer.settingsPath)
        try installer.install(from: source)
        let second = try String(contentsOf: installer.settingsPath)
        XCTAssertEqual(first, second)
    }

    func testUninstallRemovesEverything() throws {
        try installer.install(from: source)
        try installer.uninstall()
        XCTAssertFalse(installer.isInstalled)
        XCTAssertFalse(FileManager.default.fileExists(atPath: installer.hooksDir.path))
        let config = try readJSON()
        XCTAssertNil(config["hooks"])
    }

    func testPreservesUnrelatedHookEntries() throws {
        try writeJSON([
            "hooks": [
                "UserPromptSubmit": [
                    ["matcher": "", "hooks": [
                        ["type": "command", "command": "echo other-tool"]
                    ]]
                ],
                "PreToolUse": [
                    ["matcher": "Bash", "hooks": [
                        ["type": "command", "command": "echo someone-elses-hook"]
                    ]]
                ]
            ]
        ])

        try installer.install(from: source)

        let hooks = try readJSON()["hooks"] as! [String: Any]
        let ups = hooks["UserPromptSubmit"] as! [[String: Any]]
        let defaultBlock = ups.first { ($0["matcher"] as? String) == "" }!
        let handlers = defaultBlock["hooks"] as! [[String: Any]]
        XCTAssertEqual(handlers.count, 2, "should preserve existing handler and add ours")
        XCTAssertTrue(handlers.contains { ($0["command"] as? String) == "echo other-tool" })

        try installer.uninstall()
        let afterHooks = try readJSON()["hooks"] as! [String: Any]
        let afterUps = afterHooks["UserPromptSubmit"] as! [[String: Any]]
        let afterHandlers = (afterUps.first!["hooks"] as! [[String: Any]])
        XCTAssertEqual(afterHandlers.count, 1)
        XCTAssertEqual(afterHandlers[0]["command"] as? String, "echo other-tool")
        XCTAssertNotNil(afterHooks["PreToolUse"])
    }

    func testUninstallWithoutSettingsFileDoesNotCreateIt() throws {
        try installer.uninstall()
        XCTAssertFalse(FileManager.default.fileExists(atPath: installer.settingsPath.path))
    }

    func testIsInstalledFalseWhenHooksFilesMissing() throws {
        try installer.install(from: source)
        try FileManager.default.removeItem(
            at: installer.hooksDir.appendingPathComponent("_update.sh"))
        XCTAssertFalse(installer.isInstalled)
    }
}
