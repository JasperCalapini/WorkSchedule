import SwiftUI
import SwiftData

@main
struct GigLogApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Shift.self, Platform.self, MileageRate.self])
    }
}
