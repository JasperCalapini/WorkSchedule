import SwiftUI
import SwiftData

struct SummaryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Shift.start) private var allShifts: [Shift]
    @Query private var allExpenses: [Expense]
    @Query private var payouts: [PlatformPayout]
    @Query private var rates: [MileageRate]
    @AppStorage("setAsidePercent") private var setAsidePercent = Defaults.setAsidePercent
    @State private var year = Calendar.current.component(.year, from: .now)
    @State private var editingPayout: PayoutTarget?

    private var shifts: [Shift] { allShifts.filter { !$0.isActive && $0.year == year } }
    private var expenses: [Expense] { allExpenses.filter { $0.year == year } }
    private var years: [Int] {
        Set(allShifts.map(\.year) + allExpenses.map(\.year) + [Calendar.current.component(.year, from: .now)])
            .sorted(by: >)
    }

    var body: some View {
        NavigationStack {
            List {
                Picker("Tax year", selection: $year) {
                    ForEach(years, id: \.self) { Text(String($0)).tag($0) }
                }

                let t = Totals(shifts)
                let deduction = mileageDeduction(shifts, rates: rates)
                let expenseTotal = expenses.reduce(0) { $0 + $1.amount }
                let profit = t.income - deduction - expenseTotal
                let setAside = max(0, profit) * Double(setAsidePercent) / 100

                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Set aside for taxes").font(.subheadline)
                        Text(setAside.currency)
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text("\(setAsidePercent)% of \(max(0, profit).currency) profit. Change the % in Settings. Pay it at tax time, or add it to your W-4 withholding.")
                            .font(.footnote)
                    }
                    // Contrasts with the accent in both light and dark mode.
                    .foregroundStyle(Color(uiColor: .systemBackground))
                    .padding(.vertical, 8)
                    .listRowBackground(Color.accentColor)
                }

                Section {
                    LabeledContent("Gross income", value: t.income.currency)
                    LabeledContent("Mileage deduction", value: "− " + deduction.currency)
                    LabeledContent("Other expenses", value: "− " + expenseTotal.currency)
                    LabeledContent("Profit (Schedule C)") {
                        Text(profit.currency).bold()
                    }
                    LabeledContent("Business miles", value: t.miles.oneDecimal)
                    LabeledContent("Commute miles (not deducted)",
                                   value: shifts.reduce(0) { $0 + $1.commuteMiles }.oneDecimal)
                    LabeledContent("Hours · shifts", value: "\(t.hours.oneDecimal) · \(t.count)")
                } header: {
                    Text("\(String(year)) totals")
                } footer: {
                    Text("Each shift uses the IRS rate in effect on its date (see Settings).")
                }

                let platformGroups = groups { $0.platform }
                if !platformGroups.isEmpty {
                    Section {
                        ForEach(platformGroups) { group in
                            payoutRow(platform: group.key, logged: Totals(group.shifts).income)
                        }
                    } header: {
                        Text("Platform payouts vs your log")
                    } footer: {
                        Text("Enter what each app reports for the year (1099 or annual summary). If yours differs, report the platform’s number or ask your tax preparer.")
                    }

                    Section("By platform") {
                        ForEach(platformGroups) { group in
                            TotalsRow(title: group.key, totals: Totals(group.shifts))
                        }
                    }
                    Section("By month") {
                        ForEach(groups { String(format: "%02d", Calendar.current.component(.month, from: $0.start)) }) { group in
                            TotalsRow(title: group.shifts[0].start.formatted(.dateTime.month(.wide)),
                                      totals: Totals(group.shifts))
                        }
                    }
                }

                Section {
                    ShareLink(item: CSVFile(name: "mileage-log-\(year).csv",
                                            text: CSVExport.make(shifts: shifts, expenses: expenses, rates: rates)),
                              preview: SharePreview("Mileage log \(String(year))")) {
                        Label("Export CSV for taxes", systemImage: "square.and.arrow.up")
                    }
                } footer: {
                    Text("The IRS expects date, miles and business purpose for each trip. Keep this log with your tax records. Not tax advice.")
                }
            }
            .navigationTitle("Taxes")
            .sheet(item: $editingPayout) { target in
                PayoutEditorView(year: year, platform: target.platform,
                                 existing: payout(for: target.platform))
            }
        }
    }

    private func payout(for platform: String) -> PlatformPayout? {
        payouts.first { $0.year == year && $0.platform == platform }
    }

    @ViewBuilder
    private func payoutRow(platform: String, logged: Double) -> some View {
        let reported = payout(for: platform)
        Button { editingPayout = PayoutTarget(platform: platform) } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(platform).font(.headline)
                    Text("Logged \(logged.currency)" + (reported.map { " · Reported \($0.amount.currency)" } ?? ""))
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                if let reported {
                    let diff = logged - reported.amount
                    Text(abs(diff) < 0.01 ? "Match" : (diff > 0 ? "+" : "−") + abs(diff).currency)
                        .fontWeight(.semibold)
                        .foregroundStyle(abs(diff) < 0.01 ? Color.green : Color.orange)
                } else {
                    Text("Enter 1099").foregroundStyle(Color.accentColor)
                }
            }
        }
        .tint(.primary)
    }

    private func groups(by key: (Shift) -> String) -> [ShiftGroup] {
        Dictionary(grouping: shifts, by: key)
            .map { ShiftGroup(key: $0.key, shifts: $0.value) }
            .sorted { $0.key < $1.key }
    }
}

struct PayoutTarget: Identifiable {
    let platform: String
    var id: String { platform }
}

struct PayoutEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let year: Int
    let platform: String
    let existing: PlatformPayout?
    @State private var amount: String

    init(year: Int, platform: String, existing: PlatformPayout?) {
        self.year = year
        self.platform = platform
        self.existing = existing
        _amount = State(initialValue: existing?.amount.fieldText ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Reported ($)") {
                        TextField("0.00", text: $amount)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                } footer: {
                    Text("The total \(platform) reported paying you in \(String(year)), from your 1099 or the annual summary in the app.")
                }
                if existing != nil {
                    Button("Remove", role: .destructive) {
                        if let existing { context.delete(existing) }
                        dismiss()
                    }
                }
            }
            .navigationTitle(platform)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(parseNumber(amount) == nil)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func save() {
        let value = parseNumber(amount) ?? 0
        if let existing {
            existing.amount = value
        } else {
            context.insert(PlatformPayout(year: year, platform: platform, amount: value))
        }
        dismiss()
    }
}

struct ShiftGroup: Identifiable {
    let key: String
    let shifts: [Shift]
    var id: String { key }
}

struct Totals {
    var count = 0, hours = 0.0, miles = 0.0, income = 0.0

    init(_ shifts: [Shift]) {
        for s in shifts {
            count += 1
            hours += s.hours
            miles += s.miles
            income += s.income
        }
    }
}

struct TotalsRow: View {
    let title: String
    let totals: Totals

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                Text(totals.income.currency)
            }
            Text("\(totals.count) shifts · \(totals.hours.oneDecimal) h · \(totals.miles.oneDecimal) mi"
                 + (totals.hours > 0 ? " · \((totals.income / totals.hours).currency)/h" : ""))
                .font(.subheadline).foregroundStyle(.secondary)
        }
    }
}
