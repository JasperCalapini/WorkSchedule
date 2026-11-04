import CommonCrypto
import CryptoKit
import Foundation
import SwiftData

/// A complete copy of the app's data (including photos and routes), for moving to a new
/// phone or keeping a safe copy. Saved encrypted with a password (see `BackupCrypto`).
struct Backup: Codable, Sendable {
    static let currentVersion = 2
    static let fileExtension = "giglogbackup"

    var version = Backup.currentVersion
    var created = Date()
    var shifts: [ShiftRecord] = []
    var expenses: [ExpenseRecord] = []
    var payouts: [PayoutRecord] = []
    var platforms: [PlatformRecord] = []
    var rates: [RateRecord] = []

    struct ShiftRecord: Codable, Sendable {
        var platform: String, start: Date, end: Date?
        var odometerStart: Double?, odometerEnd: Double?
        var miles: Double, commuteMiles: Double, earnings: Double, tips: Double, notes: String
        var gpsMiles: Double?, personalGPSMiles: Double, isPersonal: Bool
        // Added in version 2; optional so version 1 backups still open.
        var gpsInterrupted: Bool?
        var odometerStartPhoto: Data?, odometerEndPhoto: Data?, routeData: Data?
    }
    struct ExpenseRecord: Codable, Sendable {
        var date: Date, category: String, amount: Double, note: String, receiptPhoto: Data?
    }
    struct PayoutRecord: Codable, Sendable { var year: Int, platform: String, amount: Double }
    struct PlatformRecord: Codable, Sendable { var name: String, sortOrder: Int }
    struct RateRecord: Codable, Sendable { var effectiveFrom: Date, rate: Double }

    enum Failure: LocalizedError {
        case notABackup
        case newerVersion

        var errorDescription: String? {
            switch self {
            case .notABackup: "That file isn't a Gig Log backup."
            case .newerVersion: "This backup was made by a newer version of Gig Log. Update the app first."
            }
        }
    }

    init() {}

    // MARK: - Export

    /// Copies everything out of the store. Runs on the main actor because it reads models;
    /// encoding and encryption happen afterwards off the main thread (`encrypted(password:)`).
    @MainActor
    init(context: ModelContext) throws {
        shifts = try context.fetch(FetchDescriptor<Shift>()).map {
            ShiftRecord(platform: $0.platform, start: $0.start, end: $0.end,
                        odometerStart: $0.odometerStart, odometerEnd: $0.odometerEnd,
                        miles: $0.miles, commuteMiles: $0.commuteMiles, earnings: $0.earnings,
                        tips: $0.tips, notes: $0.notes, gpsMiles: $0.gpsMiles,
                        personalGPSMiles: $0.personalGPSMiles, isPersonal: $0.isPersonal,
                        gpsInterrupted: $0.gpsInterrupted,
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

    var fileName: String {
        "gig-log-backup-\(created.formatted(.iso8601.year().month().day())).\(Self.fileExtension)"
    }

    /// The encrypted file contents. Binary property lists store photos as raw bytes
    /// (JSON would grow them by a third with base64).
    func encrypted(password: String) throws -> Data {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        return try BackupCrypto.encrypt(encoder.encode(self), password: password)
    }

    // MARK: - Restore

    static func readFile(at url: URL) throws -> Data {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        return try Data(contentsOf: url)
    }

    /// Decrypts and decodes a backup file. Unencrypted version 1 (JSON) backups are also accepted.
    static func decode(_ data: Data, password: String?) throws -> Backup {
        let backup: Backup
        if BackupCrypto.isEncrypted(data) {
            let plain = try BackupCrypto.decrypt(data, password: password ?? "")
            backup = try PropertyListDecoder().decode(Backup.self, from: plain)
        } else if let legacy = try? JSONDecoder().decode(Backup.self, from: data) {
            backup = legacy
        } else {
            throw Failure.notABackup
        }
        guard backup.version <= currentVersion else { throw Failure.newerVersion }
        return backup
    }

    /// Replaces everything in the app with this backup's contents. If anything fails, the
    /// app's current data is left as it was.
    @MainActor
    func restore(into context: ModelContext) throws {
        do {
            // Deleted one by one (not as a batch) so a failure can be fully rolled back.
            try deleteAll(Shift.self, in: context)
            try deleteAll(Expense.self, in: context)
            try deleteAll(PlatformPayout.self, in: context)
            try deleteAll(Platform.self, in: context)
            try deleteAll(MileageRate.self, in: context)
            insertAll(into: context)
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    @MainActor
    private func deleteAll<T: PersistentModel>(_ type: T.Type, in context: ModelContext) throws {
        for model in try context.fetch(FetchDescriptor<T>()) {
            context.delete(model)
        }
    }

    @MainActor
    private func insertAll(into context: ModelContext) {
        for r in shifts {
            let s = Shift(platform: r.platform, start: r.start, end: r.end,
                          odometerStart: r.odometerStart, odometerEnd: r.odometerEnd,
                          miles: r.miles, earnings: r.earnings, tips: r.tips, notes: r.notes)
            s.commuteMiles = r.commuteMiles
            s.gpsMiles = r.gpsMiles
            s.personalGPSMiles = r.personalGPSMiles
            s.isPersonal = r.isPersonal
            s.gpsInterrupted = r.gpsInterrupted ?? false
            s.odometerStartPhoto = r.odometerStartPhoto
            s.odometerEndPhoto = r.odometerEndPhoto
            s.routeData = r.routeData
            s.routePointCount = RoutePoint.count(in: r.routeData)
            context.insert(s)
        }
        for r in expenses {
            let e = Expense(date: r.date, amount: r.amount, note: r.note)
            e.category = r.category
            e.setReceipt(r.receiptPhoto)
            context.insert(e)
        }
        for r in payouts { context.insert(PlatformPayout(year: r.year, platform: r.platform, amount: r.amount)) }
        for r in platforms { context.insert(Platform(name: r.name, sortOrder: r.sortOrder)) }
        for r in rates { context.insert(MileageRate(effectiveFrom: r.effectiveFrom, rate: r.rate)) }
    }
}

/// Password-based encryption for backup files.
///
/// File layout: `magic (14 bytes) | salt (16) | PBKDF2 rounds (UInt32, big-endian) | AES-GCM combined box`.
/// The key is derived with PBKDF2-HMAC-SHA256; AES-256-GCM both encrypts and detects
/// tampering or a wrong password.
enum BackupCrypto {
    static let magic = Data("GIGLOG-BACKUP2".utf8)
    static let defaultRounds: UInt32 = 600_000
    /// Refuse files asking for absurd work, so a crafted file can't freeze the app.
    static let maxRounds: UInt32 = 10_000_000
    static let minimumPasswordLength = 8
    private static let saltLength = 16

    enum Failure: LocalizedError, Equatable {
        case wrongPassword
        case damaged
        case keyDerivationFailed

        var errorDescription: String? {
            switch self {
            case .wrongPassword: "Wrong password, or the file has been changed."
            case .damaged: "The backup file is damaged."
            case .keyDerivationFailed: "Couldn't prepare the encryption key."
            }
        }
    }

    static func isEncrypted(_ data: Data) -> Bool { data.starts(with: magic) }

    static func encrypt(_ plain: Data, password: String, rounds: UInt32 = defaultRounds) throws -> Data {
        let salt = SymmetricKey(size: .bits128).withUnsafeBytes { Data($0) }
        let key = try deriveKey(password: password, salt: salt, rounds: rounds)
        guard let combined = try AES.GCM.seal(plain, using: key).combined else { throw Failure.damaged }
        var out = magic
        out.append(salt)
        withUnsafeBytes(of: rounds.bigEndian) { out.append(contentsOf: $0) }
        out.append(combined)
        return out
    }

    static func decrypt(_ data: Data, password: String) throws -> Data {
        let bytes = [UInt8](data)
        let headerLength = magic.count + saltLength + 4
        guard isEncrypted(data), bytes.count > headerLength else { throw Failure.damaged }

        let salt = Data(bytes[magic.count ..< magic.count + saltLength])
        let roundsBytes = bytes[(magic.count + saltLength) ..< headerLength]
        let rounds = roundsBytes.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        guard rounds > 0, rounds <= maxRounds else { throw Failure.damaged }

        let key = try deriveKey(password: password, salt: salt, rounds: rounds)
        do {
            let box = try AES.GCM.SealedBox(combined: Data(bytes[headerLength...]))
            return try AES.GCM.open(box, using: key)
        } catch CryptoKitError.authenticationFailure {
            throw Failure.wrongPassword
        } catch {
            throw Failure.damaged
        }
    }

    static func deriveKey(password: String, salt: Data, rounds: UInt32) throws -> SymmetricKey {
        let passwordBytes = Array(password.utf8)
        var derived = [UInt8](repeating: 0, count: 32)
        let status = passwordBytes.withUnsafeBufferPointer { passwordPointer in
            salt.withUnsafeBytes { saltPointer in
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    UnsafeRawPointer(passwordPointer.baseAddress)?.assumingMemoryBound(to: CChar.self),
                    passwordBytes.count,
                    saltPointer.bindMemory(to: UInt8.self).baseAddress,
                    salt.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                    rounds,
                    &derived,
                    derived.count)
            }
        }
        guard status == Int32(kCCSuccess) else { throw Failure.keyDerivationFailed }
        return SymmetricKey(data: derived)
    }
}
