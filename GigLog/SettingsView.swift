import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Platform.sortOrder) private var platforms: [Platform]
    @Query(sort: \MileageRate.year, order: .reverse) private var rates: [MileageRate]

    @State private var newPlatform = ""
    @State private var newYear = ""
    @State private var newRate = ""

    var body: some View {
        NavigationStack {
            List {
                Section("Platforms") {
                    ForEach(platforms) { Text($0.name) }
                        .onDelete { offsets in for i in offsets { context.delete(platforms[i]) } }
                        .onMove(perform: movePlatforms)
                    HStack {
                        TextField("Add platform (e.g. Shipt)", text: $newPlatform)
                        Button("Add", action: addPlatform)
                            .disabled(newPlatform.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                Section {
                    ForEach(rates) { r in
                        LabeledContent(String(r.year), value: "$\(r.rate.formatted()) / mi")
                    }
                    .onDelete { offsets in for i in offsets { context.delete(rates[i]) } }
                    HStack {
                        TextField("Year", text: $newYear).keyboardType(.numberPad)
                        TextField("Rate (e.g. 0.70)", text: $newRate).keyboardType(.decimalPad)
                        Button("Set", action: setRate)
                    }
                } header: {
                    Text("IRS mileage rate")
                } footer: {
                    Text("Standard mileage rate per mile. Check irs.gov each year and update here.")
                }
            }
            .navigationTitle("Settings")
            .toolbar { EditButton() }
        }
    }

    private func addPlatform() {
        let name = newPlatform.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, !platforms.contains(where: { $0.name == name }) else { return }
        context.insert(Platform(name: name, sortOrder: (platforms.map(\.sortOrder).max() ?? -1) + 1))
        newPlatform = ""
    }

    private func movePlatforms(from source: IndexSet, to destination: Int) {
        var ordered = platforms
        ordered.move(fromOffsets: source, toOffset: destination)
        for (i, p) in ordered.enumerated() { p.sortOrder = i }
    }

    private func setRate() {
        guard let year = Int(newYear), let rate = parseNumber(newRate) else { return }
        if let existing = rates.first(where: { $0.year == year }) {
            existing.rate = rate
        } else {
            context.insert(MileageRate(year: year, rate: rate))
        }
        newYear = ""
        newRate = ""
    }
}
