import Foundation

enum CSVExport {
    static func make(shifts: [Shift], expenses: [Expense], rates: [MileageRate]) -> String {
        let date = formatter("yyyy-MM-dd")
        let time = formatter("HH:mm")
        let num: (Double?) -> String = { $0.map { String(format: "%.1f", $0) } ?? "" }
        let money: (Double) -> String = { String(format: "%.2f", $0) }

        var rows = [["Date", "Platform", "Start", "End", "Hours", "Odometer Start", "Odometer End",
                     "Business GPS Miles", "Personal/Commute Miles", "Business Miles", "IRS Rate", "Mileage Deduction",
                     "Earnings", "Tips", "Business Purpose", "Notes"]]
        for s in shifts.sorted(by: { $0.start < $1.start }) {
            let rate = mileageRate(on: s.start, in: rates)
            rows.append([
                date.string(from: s.start), s.platform, time.string(from: s.start),
                s.end.map { time.string(from: $0) } ?? "", String(format: "%.2f", s.hours),
                num(s.odometerStart), num(s.odometerEnd), num(s.gpsMiles), num(s.commuteMiles), num(s.miles),
                String(format: "%.3f", rate), money(s.miles * rate),
                money(s.earnings), money(s.tips), "\(s.platform) deliveries", s.notes
            ])
        }
        let t = Totals(shifts)
        let tips = shifts.reduce(0) { $0 + $1.tips }
        rows.append([])
        let commute = shifts.reduce(0) { $0 + $1.commuteMiles }
        rows.append(["TOTAL", "", "", "", String(format: "%.2f", t.hours), "", "", "",
                     num(commute), num(t.miles), "", money(mileageDeduction(shifts, rates: rates)),
                     money(t.income - tips), money(tips)])

        rows.append([])
        rows.append(["EXPENSES"])
        rows.append(["Date", "Category", "Amount", "Note", "Receipt"])
        for e in expenses.sorted(by: { $0.date < $1.date }) {
            rows.append([date.string(from: e.date), e.category, money(e.amount), e.note,
                         e.hasReceipt ? "Yes (in app)" : ""])
        }
        rows.append(["TOTAL", "", money(expenses.reduce(0) { $0 + $1.amount })])
        return rows.map { $0.map(escape).joined(separator: ",") }.joined(separator: "\n")
    }

    private static func formatter(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = format
        return f
    }

    /// Quotes a field for CSV. Text starting with `=`, `+`, `-`, `@`, tab or return is prefixed
    /// with `'` so spreadsheet apps show it as text instead of running it as a formula.
    static func escape(_ field: String) -> String {
        var value = field
        if let first = value.unicodeScalars.first, "=+-@\t\r".unicodeScalars.contains(first) {
            value = "'" + value
        }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
