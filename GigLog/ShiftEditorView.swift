import SwiftUI
import SwiftData

/// Adds a new shift, edits an existing one, or ends the shift in progress.
struct ShiftEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Platform.sortOrder) private var platforms: [Platform]

    let shift: Shift?

    @State private var platform: String
    @State private var start: Date
    @State private var end: Date
    @State private var odometerStart: String
    @State private var odometerEnd: String
    @State private var miles: String
    @State private var earnings: String
    @State private var tips: String
    @State private var notes: String

    init(shift: Shift?) {
        self.shift = shift
        let text: (Double?) -> String = { $0.map { String($0) } ?? "" }
        let money: (Double?) -> String = { ($0 ?? 0) == 0 ? "" : String($0!) }
        _platform = State(initialValue: shift?.platform ?? "")
        _start = State(initialValue: shift?.start ?? Date.now.addingTimeInterval(-3600))
        _end = State(initialValue: shift?.end ?? .now)
        _odometerStart = State(initialValue: text(shift?.odometerStart))
        _odometerEnd = State(initialValue: text(shift?.odometerEnd))
        // When ending a GPS-tracked shift, start with the GPS miles.
        let gps = shift?.gpsMiles.map { ($0 * 10).rounded() / 10 }
        let initialMiles = shift?.isActive == true ? gps : shift?.miles
        _miles = State(initialValue: (initialMiles ?? 0) == 0 ? "" : text(initialMiles))
        _earnings = State(initialValue: money(shift?.earnings))
        _tips = State(initialValue: money(shift?.tips))
        _notes = State(initialValue: shift?.notes ?? "")
    }

    private var isEnding: Bool { shift?.isActive == true }
    private var title: String { shift == nil ? "New Shift" : (isEnding ? "End Shift" : "Edit Shift") }
    private var platformNames: [String] {
        var names = platforms.map(\.name)
        if !platform.isEmpty && !names.contains(platform) { names.append(platform) }
        return names
    }
    private var isValid: Bool { !platform.isEmpty && end > start }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Platform", selection: $platform) {
                        ForEach(platformNames, id: \.self) { Text($0).tag($0) }
                    }
                    DatePicker("Start", selection: $start)
                    DatePicker("End", selection: $end)
                    if end <= start {
                        Text("End must be after start.").foregroundStyle(.red).font(.footnote)
                    }
                }
                Section {
                    numberField("Start odometer", $odometerStart)
                    numberField("End odometer", $odometerEnd)
                    if let gps = shift?.gpsMiles {
                        LabeledContent("GPS miles") {
                            Button("\(gps.oneDecimal) – use") { miles = String((gps * 10).rounded() / 10) }
                        }
                    }
                    numberField("Business miles", $miles)
                } header: {
                    Text("Mileage")
                } footer: {
                    Text("Business miles fill in from GPS or the odometer. You can also type them in.")
                }
                Section("Pay") {
                    numberField("Earnings ($)", $earnings)
                    numberField("Tips ($)", $tips)
                }
                Section("Notes") {
                    TextField("e.g. area, vehicle", text: $notes, axis: .vertical)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).disabled(!isValid) }
            }
            .onChange(of: odometerStart) { autoMiles() }
            .onChange(of: odometerEnd) { autoMiles() }
            .onAppear { if platform.isEmpty { platform = platforms.first?.name ?? "" } }
        }
    }

    private func numberField(_ label: String, _ value: Binding<String>) -> some View {
        LabeledContent(label) {
            TextField("0", text: value)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
        }
    }

    private func autoMiles() {
        if let s = parseNumber(odometerStart), let e = parseNumber(odometerEnd), e >= s {
            miles = String(((e - s) * 10).rounded() / 10)
        }
    }

    private func save() {
        let wasActive = isEnding
        let target = shift ?? Shift(platform: platform)
        target.platform = platform
        target.start = start
        target.end = end
        target.odometerStart = parseNumber(odometerStart)
        target.odometerEnd = parseNumber(odometerEnd)
        target.miles = parseNumber(miles) ?? 0
        target.earnings = parseNumber(earnings) ?? 0
        target.tips = parseNumber(tips) ?? 0
        target.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if shift == nil { context.insert(target) }
        if wasActive { LocationTracker.shared.stop() }
        dismiss()
    }
}
