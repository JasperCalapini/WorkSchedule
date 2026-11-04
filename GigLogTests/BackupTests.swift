import Foundation
import SwiftData
import Testing
@testable import GigLog

@Suite("Backup encryption")
struct BackupCryptoTests {
    // Few rounds keep the tests fast; real backups use `BackupCrypto.defaultRounds`.
    private let rounds: UInt32 = 1_000

    @Test("Encrypted data decrypts with the right password")
    func roundTrip() throws {
        let plain = Data("shift data".utf8)
        let sealed = try BackupCrypto.encrypt(plain, password: "correct horse", rounds: rounds)
        #expect(BackupCrypto.isEncrypted(sealed))
        #expect(sealed.range(of: plain) == nil)   // the contents aren't readable
        #expect(try BackupCrypto.decrypt(sealed, password: "correct horse") == plain)
    }

    @Test("A wrong password is rejected")
    func wrongPassword() throws {
        let sealed = try BackupCrypto.encrypt(Data("x".utf8), password: "correct horse", rounds: rounds)
        #expect(throws: BackupCrypto.Failure.wrongPassword) {
            try BackupCrypto.decrypt(sealed, password: "wrong horse")
        }
    }

    @Test("Changed bytes are detected")
    func tampering() throws {
        var sealed = try BackupCrypto.encrypt(Data("shift data".utf8), password: "correct horse", rounds: rounds)
        sealed[sealed.count - 1] ^= 0xFF
        #expect(throws: BackupCrypto.Failure.wrongPassword) {
            try BackupCrypto.decrypt(sealed, password: "correct horse")
        }
    }

    @Test("Each backup uses a new salt and nonce")
    func randomness() throws {
        let a = try BackupCrypto.encrypt(Data("same".utf8), password: "correct horse", rounds: rounds)
        let b = try BackupCrypto.encrypt(Data("same".utf8), password: "correct horse", rounds: rounds)
        #expect(a != b)
    }

    @Test("Truncated files and absurd key-derivation settings are refused")
    func damaged() throws {
        #expect(throws: BackupCrypto.Failure.damaged) {
            try BackupCrypto.decrypt(BackupCrypto.magic + Data([1, 2, 3]), password: "correct horse")
        }
        var sealed = try BackupCrypto.encrypt(Data("x".utf8), password: "correct horse", rounds: rounds)
        let roundsOffset = BackupCrypto.magic.count + 16
        sealed.replaceSubrange(roundsOffset ..< roundsOffset + 4, with: [0xFF, 0xFF, 0xFF, 0xFF])
        #expect(throws: BackupCrypto.Failure.damaged) {
            try BackupCrypto.decrypt(sealed, password: "correct horse")
        }
    }
}

@MainActor
@Suite("Backup and restore")
struct BackupRestoreTests {
    private func sampleStore() throws -> ModelContext {
        let context = try makeTestContext()
        Defaults.seed(context)
        let shift = Shift(platform: "DoorDash", start: date(2026, 3, 1, hour: 17), end: date(2026, 3, 1, hour: 20),
                          odometerStart: 48_213, odometerEnd: 48_240.3, miles: 24.1, earnings: 112.4, tips: 31,
                          notes: "Downtown")
        shift.commuteMiles = 3.2
        shift.gpsMiles = 23.4
        shift.personalGPSMiles = 3.2
        shift.gpsInterrupted = true
        shift.odometerStartPhoto = Data([1, 2, 3])
        shift.routeData = RoutePoint.encode([
            RoutePoint(latitude: 37, longitude: -122, time: 0, isPersonal: false),
            RoutePoint(latitude: 37.01, longitude: -122, time: 60, isPersonal: true)
        ])
        shift.routePointCount = 2
        context.insert(shift)
        let expense = Expense(date: date(2026, 3, 2), category: .tolls, amount: 4.75, note: "Bridge")
        expense.setReceipt(Data([9, 9]))
        context.insert(expense)
        context.insert(PlatformPayout(year: 2026, platform: "DoorDash", amount: 2_180))
        try context.save()
        return context
    }

    @Test("Everything survives backup → encrypt → decrypt → restore")
    func fullRoundTrip() throws {
        let source = try sampleStore()
        let file = try Backup(context: source).encrypted(password: "correct horse")
        let decoded = try Backup.decode(file, password: "correct horse")

        let target = try makeTestContext()
        target.insert(Shift(platform: "Old data that should be replaced"))
        try target.save()
        try decoded.restore(into: target)

        let shifts = try target.fetch(FetchDescriptor<Shift>())
        #expect(shifts.count == 1)
        let s = try #require(shifts.first)
        #expect(s.platform == "DoorDash")
        #expect(s.miles == 24.1)
        #expect(s.commuteMiles == 3.2)
        #expect(s.gpsMiles == 23.4)
        #expect(s.personalGPSMiles == 3.2)
        #expect(s.gpsInterrupted)
        #expect(s.odometerEnd == 48_240.3)
        #expect(s.odometerStartPhoto == Data([1, 2, 3]))
        #expect(s.routePointCount == 2)
        #expect(RoutePoint.decode(s.routeData).last?.isPersonal == true)

        let expenses = try target.fetch(FetchDescriptor<Expense>())
        #expect(expenses.first?.kind == .tolls)
        #expect(expenses.first?.receiptPhoto == Data([9, 9]))
        #expect(expenses.first?.hasReceipt == true)
        #expect(try target.fetch(FetchDescriptor<PlatformPayout>()).first?.amount == 2_180)
        #expect(try target.fetchCount(FetchDescriptor<MileageRate>()) == Defaults.rates.count)
        #expect(try target.fetchCount(FetchDescriptor<Platform>()) == Defaults.platforms.count)
    }

    @Test("Old unencrypted version 1 backups still open")
    func legacyJSON() throws {
        var legacy = Backup()
        legacy.version = 1
        legacy.platforms = [.init(name: "DoorDash", sortOrder: 0)]
        let json = try JSONEncoder().encode(legacy)
        let decoded = try Backup.decode(json, password: nil)
        #expect(decoded.platforms.first?.name == "DoorDash")
    }

    @Test("Backups from a newer app version and random files are refused")
    func refused() throws {
        var future = Backup()
        future.version = Backup.currentVersion + 1
        #expect(throws: Backup.Failure.self) {
            try Backup.decode(JSONEncoder().encode(future), password: nil)
        }
        #expect(throws: Backup.Failure.self) {
            try Backup.decode(Data("not a backup".utf8), password: nil)
        }
    }
}
