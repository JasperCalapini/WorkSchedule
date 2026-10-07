import Foundation
import CoreTransferable
import UniformTypeIdentifiers

enum CSVExport {
    static func make(shifts: [Shift], year: Int, rate: Double) -> String {
        let date = formatter("yyyy-MM-dd")
        let time = formatter("HH:mm")
        let num: (Double?) -> String = { $0.map { String($0) } ?? "" }

        var rows = [["Date", "Platform", "Start", "End", "Hours", "Odometer Start", "Odometer End",
                     "Business Miles", "Earnings", "Tips", "Business Purpose", "Notes"]]
        for s in shifts.sorted(by: { $0.start < $1.start }) {
            rows.append([
                date.string(from: s.start), s.platform, time.string(from: s.start),
                s.end.map { time.string(from: $0) } ?? "", String(format: "%.2f", s.hours),
                num(s.odometerStart), num(s.odometerEnd), num(s.miles),
                String(format: "%.2f", s.earnings), String(format: "%.2f", s.tips),
                "\(s.platform) deliveries", s.notes
            ])
        }
        let t = Totals(shifts)
        rows.append([])
        rows.append(["TOTAL", "", "", "", String(format: "%.2f", t.hours), "", "",
                     String(format: "%.1f", t.miles), String(format: "%.2f", t.income)])
        rows.append(["Mileage deduction @ $\(rate)/mi", "", "", "", "", "", "",
                     String(format: "%.2f", t.miles * rate)])
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
