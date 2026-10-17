import Foundation
import SwiftData

/// A complete copy of the app's data (including photos and routes) as one JSON file,
/// for moving to a new phone or keeping a safe copy.
struct Backup: Codable {
    var version = 1
    var created = Date()
    var shifts: [ShiftRecord] = []
    var expenses: [ExpenseRecord] = []
    var payouts: [PayoutRecord] = []
    var platforms: [PlatformRecord] = []
    var rates: [RateRecord] = []

    struct ShiftRecord: Codable {
        var platform: String, start: Date, end: Date?
        var odometerStart: Double?, odometerEnd: Double?
        var miles: Double, commuteMiles: Double, earnings: Double, tips: Double, notes: String
        var gpsMiles: Double?, personalGPSMiles: Double, isPersonal: Bool
        var odometerStartPhoto: Data?, odometerEndPhoto: Data?, routeData: Data?
    }
    struct ExpenseRecord: Codable {
        var date: Date, category: String, amount: Double, note: String, receiptPhoto: Data?
    }
    struct PayoutRecord: Codable { var year: Int, platform: String, amount: Double }
    struct PlatformRecord: Codable { var name: String, sortOrder: Int }
    struct RateRecord: Codable { var effectiveFrom: Date, rate: Double }

    // MARK: - Export

    init(context: ModelContext) throws {
        shifts = try context.fetch(FetchDescriptor<Shift>()).map {
            ShiftRecord(platform: $0.platform, start: $0.start, end: $0.end,
                        odometerStart: $0.odometerStart, odometerEnd: $0.odometerEnd,
                        miles: $0.miles, commuteMiles: $0.commuteMiles, earnings: $0.earnings,
                        tips: $0.tips, notes: $0.notes, gpsMiles: $0.gpsMiles,
                        personalGPSMiles: $0.personalGPSMiles, isPersonal: $0.isPersonal,
                        odometerStartPhoto: $0.odometerStartPhoto, odometerEndPhoto: $0.odometerEndPhoto,
                        routeData: $0.routeData)
        }
        expenses = try context.fetch(FetchDescriptor<Expense>()).map {
            ExpenseRecord(date: $0.date, category: $0.category, amount: $0.amount,
                          note: $0.note, receiptPhoto: $0.receiptPhoto)
        }
        payouts = try context.fetch(FetchDescriptor<PlatformPayout>()).map {
            PayoutRecord(year: $0.year, platform: $0.platform, amount: $0.amount)
        }
        platforms = try context.fetch(FetchDescriptor<Platform>()).map {
            PlatformRecord(name: $0.name, sortOrder: $0.sortOrder)
        }
        rates = try context.fetch(FetchDescriptor<MileageRate>()).map {
            RateRecord(effectiveFrom: $0.effectiveFrom, rate: $0.rate)
        }
    }

    /// Writes the backup to a temporary file for sharing / saving to Files.
    func writeFile() throws -> URL {
        let name = "gig-log-backup-\(created.formatted(.iso8601.year().month().day())).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try JSONEncoder().encode(self).write(to: url)
        return url
    }

    // MARK: - Restore

    static func read(from url: URL) throws -> Backup {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        return try JSONDecoder().decode(Backup.self, from: Data(contentsOf: url))
    }

    /// Replaces everything in the app with this backup's contents.
    func restore(into context: ModelContext) throws {
        try context.delete(model: Shift.self)
        try context.delete(model: Expense.self)
        try context.delete(model: PlatformPayout.self)
        try context.delete(model: Platform.self)
        try context.delete(model: MileageRate.self)

        for r in shifts {
            let s = Shift(platform: r.platform, start: r.start, end: r.end,
                          odometerStart: r.odometerStart, odometerEnd: r.odometerEnd,
                          miles: r.miles, earnings: r.earnings, tips: r.tips, notes: r.notes)
            s.commuteMiles = r.commuteMiles
            s.gpsMiles = r.gpsMiles
            s.personalGPSMiles = r.personalGPSMiles
            s.isPersonal = r.isPersonal
            s.odometerStartPhoto = r.odometerStartPhoto
            s.odometerEndPhoto = r.odometerEndPhoto
            s.routeData = r.routeData
            context.insert(s)
        }
        for r in expenses {
            let e = Expense(date: r.date, amount: r.amount, note: r.note)
            e.category = r.category
            e.receiptPhoto = r.receiptPhoto
            context.insert(e)
        }
        for r in payouts { context.insert(PlatformPayout(year: r.year, platform: r.platform, amount: r.amount)) }
        for r in platforms { context.insert(Platform(name: r.name, sortOrder: r.sortOrder)) }
        for r in rates { context.insert(MileageRate(effectiveFrom: r.effectiveFrom, rate: r.rate)) }
        try context.save()
    }
}
