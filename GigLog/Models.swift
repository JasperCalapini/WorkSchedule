import Foundation
import SwiftData

@Model
final class Shift {
    var platform: String = ""
    var start: Date = Date()
    /// nil while the shift is still in progress.
    var end: Date?
    var odometerStart: Double?
    var odometerEnd: Double?
    var miles: Double = 0
    var earnings: Double = 0
    var tips: Double = 0
    var notes: String = ""

    init(platform: String, start: Date = .now, end: Date? = nil,
         odometerStart: Double? = nil, odometerEnd: Double? = nil,
         miles: Double = 0, earnings: Double = 0, tips: Double = 0, notes: String = "") {
        self.platform = platform
        self.start = start
        self.end = end
        self.odometerStart = odometerStart
        self.odometerEnd = odometerEnd
        self.miles = miles
        self.earnings = earnings
        self.tips = tips
        self.notes = notes
    }

    var isActive: Bool { end == nil }
    var income: Double { earnings + tips }
    var year: Int { Calendar.current.component(.year, from: start) }
    var hours: Double {
        guard let end else { return 0 }
        return max(0, end.timeIntervalSince(start) / 3600)
    }
}

@Model
final class Platform {
    @Attribute(.unique) var name: String
    var sortOrder: Int

    init(name: String, sortOrder: Int) {
        self.name = name
        self.sortOrder = sortOrder
    }
}

/// IRS standard mileage rate in dollars per mile for a tax year.
@Model
final class MileageRate {
    @Attribute(.unique) var year: Int
    var rate: Double

    init(year: Int, rate: Double) {
        self.year = year
        self.rate = rate
    }
}

enum Defaults {
    static let platforms = ["DoorDash", "Amazon Flex", "Uber Eats", "Grubhub", "Instacart", "Walmart Spark"]
    // Verify each year at irs.gov; editable in Settings.
    static let rates: [Int: Double] = [2023: 0.655, 2024: 0.67, 2025: 0.70, 2026: 0.725]

    static func seed(_ context: ModelContext) {
        let platformCount = (try? context.fetchCount(FetchDescriptor<Platform>())) ?? 0
        if platformCount == 0 {
            for (i, name) in platforms.enumerated() {
                context.insert(Platform(name: name, sortOrder: i))
            }
        }
        let rateCount = (try? context.fetchCount(FetchDescriptor<MileageRate>())) ?? 0
        if rateCount == 0 {
            for (year, rate) in rates {
                context.insert(MileageRate(year: year, rate: rate))
            }
        }
    }
}

/// Rate for the given year, or the most recent earlier year if not set.
func mileageRate(for year: Int, in rates: [MileageRate]) -> Double {
    rates.filter { $0.year <= year }.max { $0.year < $1.year }?.rate ?? 0
}

func parseNumber(_ text: String) -> Double? {
    Double(text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "."))
}

extension Double {
    var currency: String { formatted(.currency(code: "USD")) }
    var oneDecimal: String { formatted(.number.precision(.fractionLength(1))) }
}
