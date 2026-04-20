import XCTest
@testable import ClaudeBlinkenlightsCore

final class FormattingTests: XCTestCase {
    func testFormatAgeBuckets() {
        XCTAssertEqual(formatAge(0),      "now")
        XCTAssertEqual(formatAge(1.9),    "now")
        XCTAssertEqual(formatAge(5),      "5s ago")
        XCTAssertEqual(formatAge(59),     "59s ago")
        XCTAssertEqual(formatAge(60),     "1m ago")
        XCTAssertEqual(formatAge(3599),   "59m ago")
        XCTAssertEqual(formatAge(3600),   "1h ago")
        XCTAssertEqual(formatAge(7200),   "2h ago")
    }
}
