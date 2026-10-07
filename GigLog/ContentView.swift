import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @AppStorage("didSeed") private var didSeed = false

    var body: some View {
        TabView {
            ShiftListView()
                .tabItem { Label("Shifts", systemImage: "car.fill") }
            SummaryView()
                .tabItem { Label("Tax Summary", systemImage: "doc.text.magnifyingglass") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .task {
            if !didSeed {
                Defaults.seed(context)
                didSeed = true
            }
        }
    }
}
