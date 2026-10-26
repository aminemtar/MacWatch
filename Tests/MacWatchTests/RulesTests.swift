import XCTest
@testable import MacWatch
final class RulesTests: XCTestCase {
    func testProcessPathsWithSpacesAndMalformedRows() {
        let row = ProcessRow.parse(" 42 120.5 2048 /Applications/My App.app/Contents/MacOS/My App")
        XCTAssertEqual(row?.pid, 42)
        XCTAssertEqual(row?.memoryMB, 2)
        XCTAssertEqual(row?.name, "/Applications/My App.app/Contents/MacOS/My App")
        XCTAssertNil(ProcessRow.parse("PID CPU RSS COMMAND"))
    }
    func testSustainedUsageAndReset() {
        var rules = DetectionRules()
        let high = ProcessRow(pid: 42, cpu: 90, memoryMB: 2, name: "worker")
        for _ in 0..<5 { XCTAssertTrue(rules.evaluate([high], idle: false).isEmpty) }
        XCTAssertEqual(rules.evaluate([high], idle: false).count, 1)
        XCTAssertTrue(rules.evaluate([high], idle: false).isEmpty)
        _ = rules.evaluate([], idle: false)
        XCTAssertTrue(rules.evaluate([high], idle: false).isEmpty)
    }
    func testIdleThresholdAndDistinctProcessIdentity() {
        var rules = DetectionRules()
        let row = ProcessRow(pid: 3, cpu: 30, memoryMB: 1, name: "test")
        for _ in 0..<6 { XCTAssertTrue(rules.evaluate([row], idle: false).isEmpty) }
        for _ in 0..<5 { XCTAssertTrue(rules.evaluate([row], idle: true).isEmpty) }
        XCTAssertEqual(rules.evaluate([row], idle: true).count, 1)
        XCTAssertTrue(rules.evaluate([ProcessRow(pid: 3, cpu: 90, memoryMB: 1, name: "replacement")], idle: true).isEmpty)
    }
}
