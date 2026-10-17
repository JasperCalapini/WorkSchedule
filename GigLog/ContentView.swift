import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @AppStorage("didSeed") private var didSeed = false

    var body: some View {
        TabView {
            ShiftListView()
                .tabItem { Label("Shifts", systemImage: "car.fill") }
            ExpensesView()
                .tabItem { Label("Expenses", systemImage: "receipt") }
            SummaryView()
                .tabItem { Label("Taxes", systemImage: "doc.text.magnifyingglass") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .task {
            if !didSeed {
                Defaults.seed(context)
                didSeed = true
            }
            resumeGPSIfNeeded()
        }
    }

    /// If the app was closed during a shift, keep tracking and the Lock Screen display going.
    private func resumeGPSIfNeeded() {
        guard let active = AppData.activeShift() else {
            LiveActivityController.end()   // clean up a stale Lock Screen display
            return
        }
        let tracker = LocationTracker.shared
        if !tracker.isTracking && active.gpsMiles != nil {
            tracker.start(for: active)
        }
        LiveActivityController.start(for: active)
    }
}
