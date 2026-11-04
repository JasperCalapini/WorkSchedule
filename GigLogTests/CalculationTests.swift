import Foundation
import SwiftData
import Testing
@testable import GigLog

@MainActor
@Suite("Mileage rates and totals")
struct CalculationTests {
    @Test("Uses the rate in effect on the shift's date, including the 2026 mid-year change")
    func rateByDate() throws {
        let store = try ModelContextProvider()
        #expect(mileageRate(on: date(2025, 12, 31), in: store.rates) == 0.70)
        #expect(mileageRate(on: date(2026, 1, 1), in: store.rates) == 0.725)
        #expect(mileageRate(on: date(2026, 6, 30, hour: 23), in: store.rates) == 0.725)
        #expect(mileageRate(on: date(2026, 7, 1, hour: 0), in: store.rates) == 0.76)
        #expect(mileageRate(on: date(2027, 3, 1), in: store.rates) == 0.76)
    }

    @Test("Dates before the first rate have no rate and are reported")
    func missingRate() throws {
        let store = try ModelContextProvider()
        let old = Shift(platform: "DoorDash", start: date(2022, 5, 1), miles: 10)
        let covered = Shift(platform: "DoorDash", start: date(2025, 5, 1), miles: 10)
        #expect(mileageRateIfKnown(on: old.start, in: store.rates) == nil)
        #expect(mileageRate(on: old.start, in: store.rates) == 0)
        #expect(shiftsWithoutRate([old, covered], rates: store.rates).count == 1)
    }

    @Test("Deduction is the sum of each shift's miles × rate, rounded to cents per shift")
    func deduction() throws {
        let store = try ModelContextProvider()
        let shifts = [
            Shift(platform: "DoorDash", start: date(2026, 1, 3), miles: 31.2),   // 22.62
            Shift(platform: "Amazon Flex", start: date(2026, 7, 2), miles: 58.4) // 44.384 → 44.38
        ]
        #expect(isClose(mileageDeduction(shifts, rates: store.rates), 22.62 + 44.38))
    }

    @Test("Totals add hours, miles and income; a running shift counts no hours")
    func totals() {
        let done = Shift(platform: "DoorDash", start: date(2026, 1, 3, hour: 17),
                         end: date(2026, 1, 3, hour: 20), miles: 30, earnings: 80, tips: 20)
        let running = Shift(platform: "DoorDash", start: .now, miles: 5, earnings: 0)
        let t = Totals([done, running])
        #expect(t.count == 2)
        #expect(isClose(t.hours, 3))
        #expect(isClose(t.miles, 35))
        #expect(isClose(t.income, 100))
        #expect(running.hours == 0)
    }

    @Test func uniquePlatformNamesKeepOrder() {
        let names = uniqueNames([Platform(name: "DoorDash", sortOrder: 0),
                                 Platform(name: "Amazon Flex", sortOrder: 1),
                                 Platform(name: "DoorDash", sortOrder: 2)])
        #expect(names == ["DoorDash", "Amazon Flex"])
    }

    @Test func rounding() {
        #expect(24.149.roundedToTenth == 24.1)
        #expect(24.16.roundedToTenth == 24.2)
        #expect(44.384.roundedToCents == 44.38)
        #expect(0.0.fieldText.isEmpty)
    }

    @Test func expenseCategoryFallsBackToOther() {
        let expense = Expense(amount: 5)
        expense.category = "Something old"
        #expect(expense.kind == .other)
    }
}

/// Seeds the default IRS rates into an in-memory store.
@MainActor
struct ModelContextProvider {
    /// Kept alive so the fetched models stay valid.
    let context: ModelContext
    let rates: [MileageRate]

    init() throws {
        context = try makeTestContext()
        Defaults.seed(context)
        rates = try context.fetch(FetchDescriptor<MileageRate>())
    }
}
