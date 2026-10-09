import SwiftUI
import SwiftData

@main
struct GigLogApp: App {
    /// Data is stored on this iPhone only (no iCloud sync).
    let container: ModelContainer = {
        let schema = Schema([Shift.self, Expense.self, PlatformPayout.self, Platform.self, MileageRate.self])
        let config = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("Could not open the data store: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
