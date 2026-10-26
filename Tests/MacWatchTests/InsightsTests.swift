import XCTest
@testable import MacWatch
final class InsightsTests: XCTestCase {
    func testCPUIntervalAndCounterReset() {
        XCTAssertEqual(Insights.cpuPercent(previous: [10, 10, 60, 20], current: [20, 20, 120, 40]), 40)
        XCTAssertNil(Insights.cpuPercent(previous: [10, 0, 0, 0], current: [1, 0, 0, 0]))
        XCTAssertNil(Insights.cpuPercent(previous: [1, 2, 3, 4], current: [1, 2, 3, 4]))
    }
    func testRangeFiltersAndCombinesApps() {
        let start = Date(timeIntervalSince1970: 1000)
        let rows = [UsageSlice(date: start.addingTimeInterval(-1), app: "Old", seconds: 500), UsageSlice(date: start, app: "Editor", seconds: 5), UsageSlice(date: start.addingTimeInterval(5), app: "Editor", seconds: 5)]
        let result = Insights.appTotals(rows, since: start)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.seconds, 10)
    }
    func testHeatAdviceTakesPriority() {
        XCTAssertTrue(Insights.hint(cpu: 2, thermal: "Hot", idle: false).contains("thermal pressure"))
        XCTAssertTrue(Insights.hint(cpu: nil, thermal: "Normal", idle: false).contains("first CPU"))
        XCTAssertTrue(Insights.hint(cpu: 30, thermal: "Normal", idle: true).contains("away"))
    }
}
