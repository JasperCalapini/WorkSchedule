import Foundation
import SwiftData

// Every property has a default value (or is optional) so new fields can be added
// later with a lightweight migration. See `GigLogSchemaV1` / `GigLogMigrationPlan`.

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
    /// Business miles counted by GPS; nil when GPS tracking wasn't used for this shift.
    var gpsMiles: Double?
    /// Miles counted by GPS while in personal mode (errands).
    var personalGPSMiles: Double = 0
    /// True while the driver has switched to personal mode during the shift.
    var isPersonal: Bool = false
    /// True if GPS tracking stopped for a while during the shift (e.g. the app was closed),
    /// so GPS miles may be low and the odometer should be used.
    var gpsInterrupted: Bool = false
    /// Number of points in `routeData`; lets lists check for a route without loading it.
    var routePointCount: Int = 0
    @Attribute(.externalStorage) var odometerStartPhoto: Data?
    @Attribute(.externalStorage) var odometerEndPhoto: Data?
    /// GPS route recorded during the shift (see RoutePoint.encode).
    @Attribute(.externalStorage) var routeData: Data?

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
    /// Mirrors `receiptPhoto != nil`, so lists and exports don't load every photo into memory
    /// just to show "Receipt". Always change the photo through `setReceipt(_:)`.
    var hasReceipt: Bool = false
    @Attribute(.externalStorage) var receiptPhoto: Data?

    init(date: Date = .now, category: ExpenseCategory = .other, amount: Double = 0, note: String = "") {
        self.date = date
        self.category = category.rawValue
        self.amount = amount
        self.note = note
    }

    var year: Int { Calendar.current.component(.year, from: date) }
    var kind: ExpenseCategory { ExpenseCategory(rawValue: category) ?? .other }

    func setReceipt(_ photo: Data?) {
        receiptPhoto = photo
        hasReceipt = photo != nil
    }
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

// MARK: - Schema versions

/// The first released data model. When a model changes in a way SwiftData can't migrate
/// on its own (renaming or changing a property's type), add `GigLogSchemaV2` with copies
/// of the changed models and a `MigrationStage` below. Adding a property with a default
/// value needs no new version.
enum GigLogSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
    static var models: [any PersistentModel.Type] {
        [Shift.self, Expense.self, PlatformPayout.self, Platform.self, MileageRate.self]
    }
}

enum GigLogMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [GigLogSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}

// MARK: - Settings

/// Keys for settings stored in UserDefaults (`@AppStorage`). Use these instead of string literals.
enum SettingsKey {
    static let didSeed = "didSeed"
    static let useGPS = "useGPS"
    static let recordRoute = "recordRoute"
    static let setAsidePercent = "setAsidePercent"
    static let weeklyGoal = "weeklyGoal"
    static let requireFaceID = "requireFaceID"
    static let didBackfillRouteCounts = "didBackfillRouteCounts"
    static let didBackfillReceipts = "didBackfillReceipts"

    /// A Bool setting that defaults to `true` when it has never been set.
    static func flag(_ key: String, defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: key) as? Bool ?? true
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

enum Maintenance {
    /// Fills in `routePointCount` for shifts recorded before that field existed (runs once).
    static func backfillRouteCounts(_ context: ModelContext) {
        let shifts = (try? context.fetch(FetchDescriptor<Shift>(predicate: #Predicate<Shift> { $0.routePointCount == 0 }))) ?? []
        for shift in shifts where shift.routeData != nil {
            shift.routePointCount = RoutePoint.count(in: shift.routeData)
        }
    }

    /// Fills in `Expense.hasReceipt` for expenses saved before that field existed (runs once).
    static func backfillReceiptFlags(_ context: ModelContext) {
        let expenses = (try? context.fetch(FetchDescriptor<Expense>(predicate: #Predicate<Expense> { !$0.hasReceipt }))) ?? []
        for expense in expenses where expense.receiptPhoto != nil {
            expense.hasReceipt = true
        }
    }
}

// MARK: - Calculations

/// Platform names in order, without duplicates.
func uniqueNames(_ platforms: [Platform]) -> [String] {
    var seen = Set<String>()
    return platforms.map(\.name).filter { seen.insert($0).inserted }
}

/// The rate in effect on the given date, or nil if no rate covers it.
func mileageRateIfKnown(on date: Date, in rates: [MileageRate]) -> Double? {
    rates.filter { $0.effectiveFrom <= date }.max { $0.effectiveFrom < $1.effectiveFrom }?.rate
}

/// The rate in effect on the given date (0 if none is set — see `shiftsWithoutRate`).
func mileageRate(on date: Date, in rates: [MileageRate]) -> Double {
    mileageRateIfKnown(on: date, in: rates) ?? 0
}

func mileageDeduction(_ shifts: [Shift], rates: [MileageRate]) -> Double {
    shifts.reduce(0) { $0 + ($1.miles * mileageRate(on: $1.start, in: rates)).roundedToCents }
}

/// Shifts with business miles but no IRS rate for their date, so they'd add $0 to the deduction.
func shiftsWithoutRate(_ shifts: [Shift], rates: [MileageRate]) -> [Shift] {
    shifts.filter { $0.miles > 0 && mileageRateIfKnown(on: $0.start, in: rates) == nil }
}

// MARK: - Numbers

/// Reads a number typed or pasted by the user, following their region's format
/// ("1,206.25" in the US, "1.206,25" in Germany). Ignores a leading currency symbol.
func parseNumber(_ text: String, locale: Locale = .current) -> Double? {
    var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
    for symbol in Set([locale.currencySymbol ?? "$", "$"]) {
        cleaned = cleaned.replacingOccurrences(of: symbol, with: "")
    }
    cleaned = cleaned.trimmingCharacters(in: .whitespaces)
    guard !cleaned.isEmpty else { return nil }

    let formatter = NumberFormatter()
    formatter.locale = locale
    formatter.numberStyle = .decimal
    if let number = formatter.number(from: cleaned) {
        return number.doubleValue
    }
    // Fall back to a plain "1234.5" style number.
    return Double(cleaned)
}

extension Double {
    var currency: String { formatted(.currency(code: "USD")) }
    var oneDecimal: String { formatted(.number.precision(.fractionLength(1))) }
    var roundedToTenth: Double { (self * 10).rounded() / 10 }
    var roundedToCents: Double { (self * 100).rounded() / 100 }
    /// Text for an editable field in the user's number format; empty when zero.
    var fieldText: String {
        self == 0 ? "" : formatted(.number.grouping(.never).precision(.fractionLength(0...2)))
    }
}
