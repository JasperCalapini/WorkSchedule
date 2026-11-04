import OSLog
import SwiftData
import SwiftUI

@main
struct GigLogApp: App {
    init() {
        ExportFiles.removeAll()
        // iOS may relaunch the app in the background to deliver location updates for a
        // running shift (for example after it was closed to free memory). Resume right
        // away instead of waiting for the screen to appear.
        if AppData.loadError == nil {
            ShiftControl.resumeIfNeeded()
        }
    }

    var body: some Scene {
        WindowGroup {
            if let error = AppData.loadError {
                StoreErrorView(error: error)
            } else {
                LockGate {
                    ContentView()
                }
                .modelContainer(AppData.container)
            }
        }
    }
}

/// The app's data store, shared by the UI, Shortcuts actions and the Lock Screen controls.
/// Data is stored on this iPhone only (no iCloud sync).
@MainActor
enum AppData {
    private static let loaded = load()

    static var container: ModelContainer { loaded.container }
    /// Set when the saved data couldn't be opened. The app then shows `StoreErrorView`
    /// and works on an empty in-memory store so nothing is overwritten.
    static var loadError: Error? { loaded.error }
    static var context: ModelContext { container.mainContext }

    private static func load() -> (container: ModelContainer, error: Error?) {
        let schema = Schema(versionedSchema: GigLogSchemaV1.self)
        do {
            let config = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, migrationPlan: GigLogMigrationPlan.self,
                                               configurations: config)
            return (container, nil)
        } catch {
            Log.data.fault("Could not open the data store: \(error.localizedDescription, privacy: .public)")
            let memory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            // An in-memory store with this schema can't fail to open.
            // swiftlint:disable:next force_try
            return (try! ModelContainer(for: schema, configurations: memory), error)
        }
    }

    static func activeShift() -> Shift? {
        let descriptor = FetchDescriptor<Shift>(predicate: #Predicate<Shift> { $0.end == nil })
        return (try? context.fetch(descriptor))?.first
    }

    /// Saves pending changes, logging (not hiding) any failure.
    static func save(_ reason: String = "save") {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            Log.data.error("\(reason, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }
}

/// Unified logging categories (view in Console.app or Xcode).
enum Log {
    static let data = Logger(subsystem: "GigLog", category: "data")
    static let location = Logger(subsystem: "GigLog", category: "location")
    static let export = Logger(subsystem: "GigLog", category: "export")
}

/// Files created for sharing (CSV, PDF, backups) live in one temporary folder that is
/// emptied on every launch, so copies of personal data don't pile up.
enum ExportFiles {
    static var directory: URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Exports", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func url(named name: String) -> URL {
        directory.appendingPathComponent(name)
    }

    static func write(_ data: Data, named name: String) throws -> URL {
        let url = url(named: name)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        return url
    }

    static func removeAll() {
        try? FileManager.default.removeItem(at: directory)
    }
}

/// Shown instead of the app if the saved data can't be opened, so a bad update
/// never crashes on launch or overwrites the user's data.
struct StoreErrorView: View {
    let error: Error

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.orange)
            Text("Gig Log couldn't open your data").font(.title2.bold())
            Text("Your data hasn't been deleted. Update the app or reinstall it from Xcode. If that doesn't help, contact the developer with this message:")
                .multilineTextAlignment(.center)
            Text(error.localizedDescription)
                .font(.footnote.monospaced())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .padding(32)
    }
}
