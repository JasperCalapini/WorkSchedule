import SwiftUI
import SwiftData

struct ExpensesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]

    @State private var editing: Expense?
    @State private var addingNew = false

    private var thisYear: Int { Calendar.current.component(.year, from: .now) }
    private var months: [MonthKey] {
        var seen = Set<String>()
        return expenses.compactMap { e in
            let key = e.date.formatted(.dateTime.year().month(.twoDigits))
            return seen.insert(key).inserted ? MonthKey(key: key, date: e.date) : nil
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("\(String(thisYear)) expenses") {
                        Text(expenses.filter { $0.year == thisYear }.reduce(0) { $0 + $1.amount }.currency)
                            .font(.title2.bold())
                            .monospacedDigit()
                    }
                } footer: {
                    Text("Parking, tolls, phone share, bags, chargers. Don’t add gas or repairs — the mileage rate already covers them.")
                }

                if expenses.isEmpty {
                    Text("No expenses yet. Tap + to add one.").foregroundStyle(.secondary)
                }

                ForEach(months) { month in
                    let items = expenses.filter {
                        Calendar.current.isDate($0.date, equalTo: month.date, toGranularity: .month)
                    }
                    Section(month.date.formatted(.dateTime.month(.wide).year())) {
                        ForEach(items) { expense in
                            Button { editing = expense } label: { ExpenseRow(expense: expense) }
                                .tint(.primary)
                        }
                        .onDelete { offsets in
                            for i in offsets { context.delete(items[i]) }
                        }
                    }
                }
            }
            .navigationTitle("Expenses")
            .toolbar {
                Button { addingNew = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Add expense")
            }
            .sheet(isPresented: $addingNew) { ExpenseEditorView(expense: nil) }
            .sheet(item: $editing) { ExpenseEditorView(expense: $0) }
        }
    }
}

struct MonthKey: Identifiable {
    let key: String
    let date: Date
    var id: String { key }
}

struct ExpenseRow: View {
    let expense: Expense

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: expense.kind.symbol)
                .frame(width: 36, height: 36)
                .background(Color.accentColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 9))
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(expense.category).font(.headline)
                Text([expense.date.formatted(date: .abbreviated, time: .omitted),
                      expense.note.isEmpty ? nil : expense.note,
                      expense.receiptPhoto == nil ? nil : "Receipt"]
                        .compactMap { $0 }.joined(separator: " · "))
                    .font(.subheadline).foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Text(expense.amount.currency).monospacedDigit()
        }
    }
}

struct ExpenseEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let expense: Expense?

    @State private var date: Date
    @State private var category: ExpenseCategory
    @State private var amount: String
    @State private var note: String
    @State private var receipt: Data?

    init(expense: Expense?) {
        self.expense = expense
        _date = State(initialValue: expense?.date ?? .now)
        _category = State(initialValue: expense?.kind ?? .parking)
        _amount = State(initialValue: expense?.amount.fieldText ?? "")
        _note = State(initialValue: expense?.note ?? "")
        _receipt = State(initialValue: expense?.receiptPhoto)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Category", selection: $category) {
                        ForEach(ExpenseCategory.allCases) { Label($0.rawValue, systemImage: $0.symbol).tag($0) }
                    }
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    LabeledContent("Amount ($)") {
                        TextField("0.00", text: $amount)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    TextField("Note (e.g. airport parking)", text: $note)
                } footer: {
                    if category == .phone {
                        Text("Enter only the business share, e.g. 40% of your monthly bill.")
                    }
                }
                Section("Receipt") {
                    PhotoField(title: "Receipt photo", data: $receipt)
                }
            }
            .navigationTitle(expense == nil ? "New Expense" : "Edit Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled((parseNumber(amount) ?? 0) <= 0)
                }
            }
        }
    }

    private func save() {
        let target = expense ?? Expense()
        target.date = date
        target.category = category.rawValue
        target.amount = parseNumber(amount) ?? 0
        target.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        target.receiptPhoto = receipt
        if expense == nil { context.insert(target) }
        dismiss()
    }
}
