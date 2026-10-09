import Foundation
import SwiftData

// Every property has a default value (or is optional) so new fields can be added
// later without breaking existing data.

@Model
final class Shift {
    var platform: String = ""
    var start: Date = Date()
    /// nil while the shift is still in progress.
    var end: Date?
    var odometerStart: Double?
    var odometerEnd: Double?
    /// Business miles (deductible).
    var miles: Double = 0
    /// Commute / personal miles driven during the shift; logged but not deducted.
    var commuteMiles: Double = 0
    var earnings: Double = 0
    var tips: Double = 0
    var notes: String = ""
    /// Miles counted by GPS; nil when GPS tracking wasn't used for this shift.
    var gpsMiles: Double?
    @Attribute(.externalStorage) var odometerStartPhoto: Data?
    @Attribute(.externalStorage) var odometerEndPhoto: Data?

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

/// A deductible business expense other than driving (parking, tolls, phone share, supplies...).
@Model
final class Expense {
    var date: Date = Date()
    var category: String = ExpenseCategory.other.rawValue
    var amount: Double = 0
    var note: String = ""
    @Attribute(.externalStorage) var receiptPhoto: Data?

    init(date: Date = .now, category: ExpenseCategory = .other, amount: Double = 0, note: String = "") {
        self.date = date
        self.category = category.rawValue
        self.amount = amount
        self.note = note
    }

    var year: Int { Calendar.current.component(.year, from: date) }
    var kind: ExpenseCategory { ExpenseCategory(rawValue: category) ?? .other }
}

enum ExpenseCategory: String, CaseIterable, Identifiable {
    case parking = "Parking"
    case tolls = "Tolls"
    case phone = "Phone (business share)"
    case supplies = "Supplies"
    case other = "Other"

    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .parking: "parkingsign"
        case .tolls: "road.lanes"
        case .phone: "iphone"
        case .supplies: "bag"
        case .other: "tag"
        }
    }
}

/// What a platform reported paying you for a year (1099 or annual summary).
@Model
final class PlatformPayout {
    var year: Int = 0
    var platform: String = ""
    var amount: Double = 0

    init(year: Int, platform: String, amount: Double) {
        self.year = year
        self.platform = platform
        self.amount = amount
    }
}

@Model
final class Platform {
    var name: String = ""
    var sortOrder: Int = 0

    init(name: String, sortOrder: Int) {
        self.name = name
        self.sortOrder = sortOrder
    }
}

/// IRS standard mileage rate in dollars per mile, in effect from a given date.
@Model
final class MileageRate {
    var effectiveFrom: Date = Date()
    var rate: Double = 0

    init(effectiveFrom: Date, rate: Double) {
        self.effectiveFrom = effectiveFrom
        self.rate = rate
    }
}

enum Defaults {
    static let platforms = ["DoorDash", "Amazon Flex", "Uber Eats", "Grubhub", "Instacart", "Walmart Spark"]
    // Verify at irs.gov; editable in Settings. 2026 changed mid-year.
    static let rates: [(year: Int, month: Int, rate: Double)] = [
        (2023, 1, 0.655), (2024, 1, 0.67), (2025, 1, 0.70), (2026, 1, 0.725), (2026, 7, 0.76)
    ]
    static let setAsidePercent = 25

    static func seed(_ context: ModelContext) {
        let platformCount = (try? context.fetchCount(FetchDescriptor<Platform>())) ?? 0
        if platformCount == 0 {
            for (i, name) in platforms.enumerated() {
                context.insert(Platform(name: name, sortOrder: i))
            }
        }
        let rateCount = (try? context.fetchCount(FetchDescriptor<MileageRate>())) ?? 0
        if rateCount == 0 {
            for r in rates {
                let date = Calendar.current.date(from: DateComponents(year: r.year, month: r.month, day: 1)) ?? .now
                context.insert(MileageRate(effectiveFrom: date, rate: r.rate))
            }
        }
    }
}

/// Platform names in order, without duplicates.
func uniqueNames(_ platforms: [Platform]) -> [String] {
    var seen = Set<String>()
    return platforms.map(\.name).filter { seen.insert($0).inserted }
}

/// The rate in effect on the given date.
func mileageRate(on date: Date, in rates: [MileageRate]) -> Double {
    rates.filter { $0.effectiveFrom <= date }.max { $0.effectiveFrom < $1.effectiveFrom }?.rate ?? 0
}

func mileageDeduction(_ shifts: [Shift], rates: [MileageRate]) -> Double {
    shifts.reduce(0) { $0 + $1.miles * mileageRate(on: $1.start, in: rates) }
}

func parseNumber(_ text: String) -> Double? {
    Double(text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "."))
}

extension Double {
    var currency: String { formatted(.currency(code: "USD")) }
    var oneDecimal: String { formatted(.number.precision(.fractionLength(1))) }
    /// Text for an editable field: empty when zero.
    var fieldText: String { self == 0 ? "" : String(self) }
}
