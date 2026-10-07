import SwiftUI
import SwiftData

struct SummaryView: View {
    @Query(sort: \Shift.start) private var allShifts: [Shift]
    @Query private var rates: [MileageRate]
    @State private var year = Calendar.current.component(.year, from: .now)

    private var shifts: [Shift] { allShifts.filter { !$0.isActive && $0.year == year } }
    private var years: [Int] {
        Set(allShifts.map(\.year) + [Calendar.current.component(.year, from: .now)]).sorted(by: >)
    }
    private var rate: Double { mileageRate(for: year, in: rates) }

    var body: some View {
        NavigationStack {
            List {
                Picker("Tax year", selection: $year) {
                    ForEach(years, id: \.self) { Text(String($0)).tag($0) }
                }

                let t = Totals(shifts)
                Section("\(String(year)) totals") {
                    LabeledContent("Business miles", value: t.miles.oneDecimal)
                    LabeledContent("Mileage deduction", value: (t.miles * rate).currency)
                    LabeledContent("Rate used", value: "$\(rate.formatted()) / mi")
                    LabeledContent("Gross income", value: t.income.currency)
                    LabeledContent("Hours worked", value: t.hours.oneDecimal)
                    LabeledContent("Shifts", value: String(t.count))
                }

                if !shifts.isEmpty {
                    Section("By platform") {
                        ForEach(groups { $0.platform }) { group in
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
                                            text: CSVExport.make(shifts: shifts, year: year, rate: rate)),
                              preview: SharePreview("Mileage log \(String(year))")) {
                        Label("Export CSV for taxes", systemImage: "square.and.arrow.up")
                    }
                } footer: {
                    Text("The IRS expects date, miles and business purpose for each trip. Keep this log with your tax records. Not tax advice.")
                }
            }
            .navigationTitle("Tax Summary")
        }
    }

    private func groups(by key: (Shift) -> String) -> [ShiftGroup] {
        Dictionary(grouping: shifts, by: key)
            .map { ShiftGroup(key: $0.key, shifts: $0.value) }
            .sorted { $0.key < $1.key }
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
            Text("\(totals.count) shifts · \(totals.hours.oneDecimal) h · \(totals.miles.oneDecimal) mi")
                .font(.subheadline).foregroundStyle(.secondary)
        }
    }
}
