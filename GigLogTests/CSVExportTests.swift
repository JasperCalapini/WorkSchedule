import Foundation
import Testing
@testable import GigLog

@MainActor
@Suite("CSV export")
struct CSVExportTests {
    @Test("Quotes are doubled and every field is quoted")
    func quoting() {
        #expect(CSVExport.escape(#"Say "hi""#) == #""Say ""hi""""#)
        #expect(CSVExport.escape("plain") == #""plain""#)
    }

    @Test("Text that spreadsheets would run as a formula is neutralised",
          arguments: ["=HYPERLINK(\"x\")", "+1", "-2", "@SUM(A1)", "\tTab"])
    func formulaInjection(text: String) {
        #expect(CSVExport.escape(text).hasPrefix("\"'"))
    }

    @Test("One row per shift, totals and an expenses section")
    func content() throws {
        let store = try ModelContextProvider()
        let shifts = [
            Shift(platform: "DoorDash", start: date(2026, 1, 3, hour: 17), end: date(2026, 1, 3, hour: 20),
                  miles: 31.2, earnings: 80, tips: 20, notes: "=cmd"),
            Shift(platform: "Amazon Flex", start: date(2026, 7, 2, hour: 10), end: date(2026, 7, 2, hour: 14),
                  miles: 58.4, earnings: 96)
        ]
        let expenses = [Expense(date: date(2026, 2, 1), category: .parking, amount: 6, note: "Garage")]
        let csv = CSVExport.make(shifts: shifts, expenses: expenses, rates: store.rates)
        let lines = csv.components(separatedBy: "\n")

        let headerColumns = lines[0].components(separatedBy: "\",\"").count
        #expect(headerColumns == 16)
        #expect(lines[1].contains("\"DoorDash\""))
        #expect(lines[1].contains("\"'=cmd\""))
        #expect(lines.contains { $0.hasPrefix("\"TOTAL\"") && $0.contains("\"67.00\"") && $0.contains("\"89.6\"") })
        #expect(lines.contains("\"EXPENSES\""))
        #expect(lines.contains { $0.contains("\"Parking\"") && $0.contains("\"6.00\"") })
    }
}
