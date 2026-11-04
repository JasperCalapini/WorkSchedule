import Foundation
import Testing
@testable import GigLog

@MainActor
@Suite("PDF report and insights")
struct ReportAndInsightsTests {
    @Test("The PDF report is a valid PDF, even with no data")
    func pdf() throws {
        let store = try ModelContextProvider()
        let shift = Shift(platform: "DoorDash", start: date(2026, 1, 3, hour: 17), end: date(2026, 1, 3, hour: 20),
                          miles: 31.2, earnings: 80)
        for shifts in [[shift], []] {
            let data = ReportPDF.make(year: 2026, shifts: shifts, expenses: [], payouts: [],
                                      rates: store.rates, setAsidePercent: 25)
            #expect(data.starts(with: Data("%PDF".utf8)))
        }
    }

    @Test("Hours map to the right time-of-day block", arguments: [
        (6, TimeBlock.morning), (11, TimeBlock.lunch), (13, TimeBlock.lunch), (15, TimeBlock.afternoon),
        (18, TimeBlock.dinner), (22, TimeBlock.late), (2, TimeBlock.late)
    ])
    func timeBlocks(hour: Int, expected: TimeBlock) {
        #expect(TimeBlock(for: date(2026, 1, 5, hour: hour)) == expected)
    }
}
