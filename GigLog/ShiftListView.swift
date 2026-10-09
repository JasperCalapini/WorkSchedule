import SwiftUI
import SwiftData

struct ShiftListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Shift.start, order: .reverse) private var shifts: [Shift]
    @Query(sort: \Platform.sortOrder) private var platforms: [Platform]
    @AppStorage("useGPS") private var useGPS = true

    @State private var startPlatform = ""
    @State private var startOdometer = ""
    @State private var startPhoto: Data?
    @State private var period: Period = .week
    @State private var editing: Shift?
    @State private var addingNew = false
    private var tracker: LocationTracker { .shared }

    private var activeShift: Shift? { shifts.first { $0.isActive } }
    private var completed: [Shift] { shifts.filter { !$0.isActive } }

    var body: some View {
        NavigationStack {
            List {
                Section { PeriodStatsView(shifts: completed, period: $period) }

                if let active = activeShift {
                    activeSection(active)
                } else {
                    Section {
                        Picker("Platform", selection: $startPlatform) {
                            ForEach(uniqueNames(platforms), id: \.self) { Text($0).tag($0) }
                        }
                        Toggle("Track miles with GPS", isOn: $useGPS)
                        TextField(useGPS ? "Start odometer (backup, optional)" : "Start odometer",
                                  text: $startOdometer)
                            .keyboardType(.decimalPad)
                        PhotoField(title: "Odometer photo", data: $startPhoto)
                        Button("Start shift now", action: startShift)
                            .buttonStyle(.borderedProminent)
                            .frame(maxWidth: .infinity)
                            .disabled(startPlatform.isEmpty)
                    } header: {
                        Text("Start a shift")
                    } footer: {
                        if useGPS {
                            Text("GPS keeps counting while you use other apps. The odometer and a photo of it are your backup proof.")
                        }
                    }
                }

                Section("History") {
                    if completed.isEmpty {
                        Text("No shifts yet.").foregroundStyle(.secondary)
                    }
                    ForEach(completed) { shift in
                        Button { editing = shift } label: { ShiftRow(shift: shift) }
                            .tint(.primary)
                    }
                    .onDelete { offsets in
                        for i in offsets { context.delete(completed[i]) }
                    }
                }
            }
            .navigationTitle("Gig Log")
            .toolbar {
                Button { addingNew = true } label: { Image(systemName: "plus") }
            }
            .sheet(isPresented: $addingNew) { ShiftEditorView(shift: nil) }
            .sheet(item: $editing) { ShiftEditorView(shift: $0) }
            .onAppear { if startPlatform.isEmpty { startPlatform = platforms.first?.name ?? "" } }
            .onChange(of: platforms.count) {
                if startPlatform.isEmpty { startPlatform = platforms.first?.name ?? "" }
            }
        }
    }

    @ViewBuilder
    private func activeSection(_ active: Shift) -> some View {
        Section("Shift in progress") {
            VStack(alignment: .leading, spacing: 4) {
                Text(active.platform).font(.headline)
                Text("Started \(active.start.formatted(date: .omitted, time: .shortened))")
                    .foregroundStyle(.secondary)
                Text(active.start, style: .timer)
                    .font(.system(.largeTitle, design: .rounded).monospacedDigit())
                if let gps = active.gpsMiles {
                    Label("\(gps.oneDecimal) mi (GPS)", systemImage: "location.fill")
                        .font(.title3)
                }
                if let odo = active.odometerStart {
                    Text("Start odometer: \(odo.oneDecimal)").foregroundStyle(.secondary)
                }
            }
            if active.gpsMiles != nil && tracker.isDenied {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Location access is off, so GPS can't count miles. Turn it on, or enter your odometer when you end the shift.")
                        .font(.footnote).foregroundStyle(.red)
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        Link("Open Settings", destination: url).font(.footnote)
                    }
                }
            }
            Button("End shift") { editing = active }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
            Button("Discard shift", role: .destructive) {
                tracker.stop()
                context.delete(active)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func startShift() {
        let shift = Shift(platform: startPlatform, odometerStart: parseNumber(startOdometer))
        shift.odometerStartPhoto = startPhoto
        context.insert(shift)
        if useGPS { tracker.start(for: shift) }
        startOdometer = ""
        startPhoto = nil
    }
}

struct ShiftRow: View {
    let shift: Shift

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(shift.platform).font(.headline)
                Text(shift.start.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline).foregroundStyle(.secondary)
                Text("\(shift.hours.formatted(.number.precision(.fractionLength(2)))) h · \(shift.miles.oneDecimal) mi")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Text(shift.income.currency).font(.headline)
        }
    }
}

enum Period: String, CaseIterable, Identifiable {
    case week = "This week"
    case month = "This month"
    var id: String { rawValue }
}

/// Earnings, hours and miles for the current week or month, plus $/hour and $/mile.
struct PeriodStatsView: View {
    let shifts: [Shift]
    @Binding var period: Period

    private var inPeriod: [Shift] {
        let component: Calendar.Component = period == .week ? .weekOfYear : .month
        return shifts.filter { Calendar.current.isDate($0.start, equalTo: .now, toGranularity: component) }
    }

    var body: some View {
        let t = Totals(inPeriod)
        VStack(spacing: 12) {
            Picker("Period", selection: $period) {
                ForEach(Period.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                GridRow {
                    stat("Earned", t.income.currency)
                    stat("Hours", t.hours.oneDecimal)
                    stat("Business mi", t.miles.oneDecimal)
                }
                GridRow {
                    stat("Per hour", t.hours > 0 ? (t.income / t.hours).currency : "–")
                    stat("Per mile", t.miles > 0 ? (t.income / t.miles).currency : "–")
                    stat("Shifts", String(t.count))
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
