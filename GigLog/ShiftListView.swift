import SwiftUI
import SwiftData

struct ShiftListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Shift.start, order: .reverse) private var shifts: [Shift]
    @Query(sort: \Platform.sortOrder) private var platforms: [Platform]

    @State private var startPlatform = ""
    @State private var startOdometer = ""
    @State private var editing: Shift?
    @State private var addingNew = false

    private var activeShift: Shift? { shifts.first { $0.isActive } }
    private var completed: [Shift] { shifts.filter { !$0.isActive } }

    var body: some View {
        NavigationStack {
            List {
                if let active = activeShift {
                    Section("Shift in progress") {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(active.platform).font(.headline)
                            Text("Started \(active.start.formatted(date: .omitted, time: .shortened))")
                                .foregroundStyle(.secondary)
                            Text(active.start, style: .timer)
                                .font(.system(.largeTitle, design: .rounded).monospacedDigit())
                            if let odo = active.odometerStart {
                                Text("Odometer: \(odo.oneDecimal)").foregroundStyle(.secondary)
                            }
                        }
                        Button("End shift") { editing = active }
                            .buttonStyle(.borderedProminent)
                            .frame(maxWidth: .infinity)
                        Button("Discard shift", role: .destructive) { context.delete(active) }
                            .frame(maxWidth: .infinity)
                    }
                } else {
                    Section("Start a shift") {
                        Picker("Platform", selection: $startPlatform) {
                            ForEach(platforms) { Text($0.name).tag($0.name) }
                        }
                        TextField("Start odometer (optional)", text: $startOdometer)
                            .keyboardType(.decimalPad)
                        Button("Start shift now", action: startShift)
                            .buttonStyle(.borderedProminent)
                            .frame(maxWidth: .infinity)
                            .disabled(startPlatform.isEmpty)
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

    private func startShift() {
        context.insert(Shift(platform: startPlatform, odometerStart: parseNumber(startOdometer)))
        startOdometer = ""
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
