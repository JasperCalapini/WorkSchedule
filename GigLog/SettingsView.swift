import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Platform.sortOrder) private var platforms: [Platform]
    @Query(sort: \MileageRate.effectiveFrom, order: .reverse) private var rates: [MileageRate]

    @AppStorage("setAsidePercent") private var setAsidePercent = Defaults.setAsidePercent
    @State private var newPlatform = ""
    @State private var newRateDate = Date.now
    @State private var newRate = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Stepper(value: $setAsidePercent, in: 0...50, step: 1) {
                        LabeledContent("Set aside", value: "\(setAsidePercent)%")
                    }
                    LabeledContent("iCloud sync") {
                        if FileManager.default.ubiquityIdentityToken != nil {
                            Label("Signed in", systemImage: "checkmark.icloud")
                        } else {
                            Label("Not signed in", systemImage: "icloud.slash")
                        }
                    }
                } header: {
                    Text("Taxes & sync")
                } footer: {
                    Text("Profit × this % = what the Taxes tab tells you to save. 25–30% is typical. iCloud sync works once it's turned on for the app (see README).")
                }

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
                        LabeledContent("From \(r.effectiveFrom.formatted(date: .abbreviated, time: .omitted))",
                                       value: "$\(r.rate.formatted()) / mi")
                    }
                    .onDelete { offsets in for i in offsets { context.delete(rates[i]) } }
                    DatePicker("Effective from", selection: $newRateDate, displayedComponents: .date)
                    HStack {
                        TextField("Rate (e.g. 0.70)", text: $newRate).keyboardType(.decimalPad)
                        Button("Set", action: setRate)
                    }
                } header: {
                    Text("IRS mileage rate")
                } footer: {
                    Text("IRS standard mileage rate per mile. Check irs.gov each year; the IRS sometimes changes it mid-year.")
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
        guard let rate = parseNumber(newRate) else { return }
        let day = Calendar.current.startOfDay(for: newRateDate)
        if let existing = rates.first(where: { $0.effectiveFrom == day }) {
            existing.rate = rate
        } else {
            context.insert(MileageRate(effectiveFrom: day, rate: rate))
        }
        newRate = ""
    }
}
