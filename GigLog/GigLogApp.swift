import SwiftUI
import SwiftData

@main
struct GigLogApp: App {
    var body: some Scene {
        WindowGroup {
            LockGate {
                ContentView()
            }
        }
        .modelContainer(AppData.container)
    }
}

/// The app's data store, shared by the UI, Shortcuts actions and the Lock Screen controls.
/// Data is stored on this iPhone only (no iCloud sync).
@MainActor
enum AppData {
    static let container: ModelContainer = {
        let schema = Schema([Shift.self, Expense.self, PlatformPayout.self, Platform.self, MileageRate.self])
        let config = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("Could not open the data store: \(error)")
        }
    }()

    static var context: ModelContext { container.mainContext }

    static func activeShift() -> Shift? {
        let shifts = (try? context.fetch(FetchDescriptor<Shift>(predicate: #Predicate<Shift> { $0.end == nil }))) ?? []
        return shifts.first
    }
}
