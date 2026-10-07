import Foundation
import CoreTransferable
import UniformTypeIdentifiers

enum CSVExport {
    static func make(shifts: [Shift], rates: [MileageRate]) -> String {
        let date = formatter("yyyy-MM-dd")
        let time = formatter("HH:mm")
        let num: (Double?) -> String = { $0.map { String(format: "%.1f", $0) } ?? "" }
        let money: (Double) -> String = { String(format: "%.2f", $0) }

        var rows = [["Date", "Platform", "Start", "End", "Hours", "Odometer Start", "Odometer End",
                     "GPS Miles", "Business Miles", "IRS Rate", "Mileage Deduction",
                     "Earnings", "Tips", "Business Purpose", "Notes"]]
        for s in shifts.sorted(by: { $0.start < $1.start }) {
            let rate = mileageRate(on: s.start, in: rates)
            rows.append([
                date.string(from: s.start), s.platform, time.string(from: s.start),
                s.end.map { time.string(from: $0) } ?? "", String(format: "%.2f", s.hours),
                num(s.odometerStart), num(s.odometerEnd), num(s.gpsMiles), num(s.miles),
                String(format: "%.3f", rate), money(s.miles * rate),
                money(s.earnings), money(s.tips), "\(s.platform) deliveries", s.notes
            ])
        }
        let t = Totals(shifts)
        let tips = shifts.reduce(0) { $0 + $1.tips }
        rows.append([])
        rows.append(["TOTAL", "", "", "", String(format: "%.2f", t.hours), "", "", "",
                     num(t.miles), "", money(mileageDeduction(shifts, rates: rates)),
                     money(t.income - tips), money(tips)])
        return rows.map { $0.map(escape).joined(separator: ",") }.joined(separator: "\n")
    }

    private static func formatter(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = format
        return f
    }

    private static func escape(_ field: String) -> String {
        "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}

struct CSVFile: Transferable {
    let name: String
    let text: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .commaSeparatedText) { file in
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(file.name)
            try file.text.write(to: url, atomically: true, encoding: .utf8)
            return SentTransferredFile(url)
        }
    }
}
