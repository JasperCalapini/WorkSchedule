import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Platform.sortOrder) private var platforms: [Platform]
    @Query(sort: \MileageRate.effectiveFrom, order: .reverse) private var rates: [MileageRate]

    @AppStorage("setAsidePercent") private var setAsidePercent = Defaults.setAsidePercent
    @AppStorage("recordRoute") private var recordRoute = true
    @AppStorage("weeklyGoal") private var weeklyGoal = 0.0
    @AppStorage("requireFaceID") private var requireFaceID = false
    @State private var newPlatform = ""
    @State private var newRateDate = Date.now
    @State private var newRate = ""
    @State private var backupURL: URL?
    @State private var importing = false
    @State private var pendingRestore: Backup?
    @State private var backupMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Stepper(value: $setAsidePercent, in: 0...50, step: 1) {
                        LabeledContent("Set aside", value: "\(setAsidePercent)%")
                    }
                } header: {
                    Text("Taxes")
                } footer: {
                    Text("Profit × this % = what the Taxes tab tells you to save. 25–30% is typical.")
                }

                Section {
                    LabeledContent("Weekly earnings goal") {
                        TextField("Off", value: $weeklyGoal, format: .currency(code: "USD"))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    Toggle("Require Face ID", isOn: $requireFaceID)
                } header: {
                    Text("Goals & privacy")
                } footer: {
                    Text("Set a goal to see a progress bar on the Shifts tab (0 turns it off). Face ID keeps your earnings and routes private.")
                }

                Section {
                    Toggle("Save route map", isOn: $recordRoute)
                } header: {
                    Text("GPS")
                } footer: {
                    Text("Saves where you drove during GPS-tracked shifts so you can review it on a map. Stored only on this iPhone, about 100–300 KB per shift.")
                }

                Section {
                    if let backupURL {
                        ShareLink(item: backupURL) {
                            Label("Save backup file…", systemImage: "square.and.arrow.up")
                        }
                    } else {
                        Button("Create backup", systemImage: "externaldrive", action: makeBackup)
                    }
                    Button("Restore from backup…", systemImage: "arrow.counterclockwise") { importing = true }
                } header: {
                    Text("Backup")
                } footer: {
                    Text("Saves everything (shifts, routes, photos, expenses) to one file. Keep it in Files, iCloud Drive or email it to yourself, then restore it on a new phone.")
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
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                do {
                    pendingRestore = try Backup.read(from: result.get())
                } catch {
                    backupMessage = "That file isn't a Gig Log backup."
                }
            }
            .confirmationDialog("Replace all data?", isPresented: Binding(
                get: { pendingRestore != nil }, set: { if !$0 { pendingRestore = nil } }
            ), titleVisibility: .visible) {
                Button("Replace with backup", role: .destructive, action: restore)
            } message: {
                if let backup = pendingRestore {
                    Text("Backup from \(backup.created.formatted(date: .abbreviated, time: .shortened)) with \(backup.shifts.count) shifts and \(backup.expenses.count) expenses. Everything currently in the app will be replaced.")
                }
            }
            .alert(backupMessage ?? "", isPresented: Binding(
                get: { backupMessage != nil }, set: { if !$0 { backupMessage = nil } }
            )) {}
        }
    }

    private func makeBackup() {
        do {
            backupURL = try Backup(context: context).writeFile()
        } catch {
            backupMessage = "Couldn't create the backup: \(error.localizedDescription)"
        }
    }

    private func restore() {
        guard let backup = pendingRestore else { return }
        pendingRestore = nil
        LocationTracker.shared.stop()
        do {
            try backup.restore(into: context)
            backupURL = nil
            backupMessage = "Backup restored."
        } catch {
            backupMessage = "Restore failed: \(error.localizedDescription)"
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
