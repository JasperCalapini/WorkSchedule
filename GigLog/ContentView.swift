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

    /// If the app was closed during a GPS-tracked shift, keep tracking when it reopens.
    private func resumeGPSIfNeeded() {
        let tracker = LocationTracker.shared
        guard !tracker.isTracking else { return }
        let shifts = (try? context.fetch(FetchDescriptor<Shift>())) ?? []
        if let active = shifts.first(where: { $0.isActive && $0.gpsMiles != nil }) {
            tracker.start(for: active)
        }
    }
}
