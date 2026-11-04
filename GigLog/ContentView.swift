import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @AppStorage(SettingsKey.didSeed) private var didSeed = false
    @AppStorage(SettingsKey.didBackfillRouteCounts) private var didBackfillRouteCounts = false
    @AppStorage(SettingsKey.didBackfillReceipts) private var didBackfillReceipts = false

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
            if !didBackfillRouteCounts {
                Maintenance.backfillRouteCounts(context)
                didBackfillRouteCounts = true
            }
            if !didBackfillReceipts {
                Maintenance.backfillReceiptFlags(context)
                didBackfillReceipts = true
            }
            // Also runs at launch; repeating it here starts the Lock Screen display,
            // which iOS only allows while the app is on screen.
            ShiftControl.resumeIfNeeded()
        }
    }
}
