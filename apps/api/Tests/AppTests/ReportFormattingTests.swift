import XCTVapor
@testable import App

final class ReportFormattingTests: XCTestCase {
    func testUtilizationDividesBookedByCapacity() {
        XCTAssertEqual(ReportFormatting.utilization(bookedCount: 5, capacity: 10), 0.5)
    }

    func testUtilizationIsZeroForZeroCapacity() {
        XCTAssertEqual(ReportFormatting.utilization(bookedCount: 0, capacity: 0), 0)
    }

    func testCsvEscapeLeavesPlainFieldUnchanged() {
        XCTAssertEqual(ReportFormatting.csvEscape("Yoga"), "Yoga")
    }

    func testCsvEscapeQuotesFieldContainingComma() {
        XCTAssertEqual(ReportFormatting.csvEscape("Yoga, Advanced"), "\"Yoga, Advanced\"")
    }

    func testCsvEscapeDoublesEmbeddedQuotes() {
        XCTAssertEqual(ReportFormatting.csvEscape("Say \"hi\""), "\"Say \"\"hi\"\"\"")
    }
}
