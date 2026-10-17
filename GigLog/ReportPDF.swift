import UIKit

/// Builds a year-end tax report PDF: summary, platform payouts, expenses and the full mileage log.
enum ReportPDF {
    static func make(year: Int, shifts: [Shift], expenses: [Expense], payouts: [PlatformPayout],
                     rates: [MileageRate], setAsidePercent: Int) -> Data {
        let page = CGRect(x: 0, y: 0, width: 612, height: 792)   // US Letter
        let writer = PageWriter(page: page)
        let sortedShifts = shifts.sorted { $0.start < $1.start }
        let t = Totals(sortedShifts)
        let deduction = mileageDeduction(sortedShifts, rates: rates)
        let expenseTotal = expenses.reduce(0) { $0 + $1.amount }
        let profit = t.income - deduction - expenseTotal
        let personal = sortedShifts.reduce(0) { $0 + $1.commuteMiles }

        return writer.renderer.pdfData { ctx in
            writer.begin(ctx)
            writer.title("Gig Log — \(year) Tax Report")
            writer.text("Generated \(Date.now.formatted(date: .long, time: .omitted)). Not tax advice.",
                        font: .systemFont(ofSize: 10), color: .secondaryLabel)
            writer.space(12)

            writer.heading("Summary")
            writer.row(["Gross income (earnings + tips)", t.income.currency])
            writer.row(["Mileage deduction (standard rate)", "− " + deduction.currency])
            writer.row(["Other expenses", "− " + expenseTotal.currency])
            writer.row(["Profit (Schedule C)", profit.currency], bold: true)
            writer.row(["Business miles", t.miles.oneDecimal])
            writer.row(["Personal / commute miles (not deducted)", personal.oneDecimal])
            writer.row(["Hours worked · shifts", "\(t.hours.oneDecimal) · \(t.count)"])
            writer.row(["Suggested set-aside (\(setAsidePercent)%)",
                        (max(0, profit) * Double(setAsidePercent) / 100).currency])
            writer.space(12)

            let byPlatform = Dictionary(grouping: sortedShifts, by: \.platform)
            if !byPlatform.isEmpty {
                writer.heading("Platforms")
                writer.row(["Platform", "Logged", "Reported (1099)", "Difference"], header: true, columns: 4)
                for name in byPlatform.keys.sorted() {
                    let logged = Totals(byPlatform[name] ?? []).income
                    let reported = payouts.first { $0.year == year && $0.platform == name }?.amount
                    writer.row([name, logged.currency, reported?.currency ?? "—",
                                reported.map { (logged - $0).currency } ?? "—"], columns: 4)
                }
                writer.space(12)
            }

            writer.heading("Expenses")
            if expenses.isEmpty {
                writer.text("None recorded.", font: .systemFont(ofSize: 10), color: .secondaryLabel)
            } else {
                writer.row(["Date", "Category", "Note", "Amount"], header: true, columns: 4)
                for e in expenses.sorted(by: { $0.date < $1.date }) {
                    writer.row([e.date.formatted(date: .numeric, time: .omitted), e.category,
                                e.note + (e.receiptPhoto == nil ? "" : " (receipt)"), e.amount.currency], columns: 4)
                }
                writer.row(["", "", "Total", expenseTotal.currency], bold: true, columns: 4)
            }
            writer.space(12)

            writer.heading("Mileage log")
            writer.row(["Date", "Platform", "Time", "Hours", "Business mi", "Personal mi", "Rate", "Deduction"],
                       header: true, columns: 8)
            for s in sortedShifts {
                let rate = mileageRate(on: s.start, in: rates)
                let time = s.start.formatted(date: .omitted, time: .shortened) + "–" +
                    (s.end?.formatted(date: .omitted, time: .shortened) ?? "")
                writer.row([s.start.formatted(date: .numeric, time: .omitted), s.platform, time,
                            s.hours.oneDecimal, s.miles.oneDecimal, s.commuteMiles.oneDecimal,
                            String(format: "$%.3f", rate), (s.miles * rate).currency], columns: 8)
            }
            writer.row(["Total", "", "", t.hours.oneDecimal, t.miles.oneDecimal, personal.oneDecimal,
                        "", deduction.currency], bold: true, columns: 8)
            writer.text("Business purpose for all business miles: delivery driving for the listed platform.",
                        font: .systemFont(ofSize: 9), color: .secondaryLabel)
        }
    }
}

/// Minimal top-to-bottom text layout that starts a new page when one fills up.
private final class PageWriter {
    let page: CGRect
    let renderer: UIGraphicsPDFRenderer
    private let margin: CGFloat = 40
    private var y: CGFloat = 0
    private var ctx: UIGraphicsPDFRendererContext?

    init(page: CGRect) {
        self.page = page
        self.renderer = UIGraphicsPDFRenderer(bounds: page)
    }

    private var width: CGFloat { page.width - margin * 2 }

    func begin(_ ctx: UIGraphicsPDFRendererContext) {
        self.ctx = ctx
        ctx.beginPage()
        y = margin
    }

    private func ensureRoom(_ height: CGFloat) {
        if y + height > page.height - margin {
            ctx?.beginPage()
            y = margin
        }
    }

    func space(_ height: CGFloat) { y += height }

    func title(_ string: String) { text(string, font: .boldSystemFont(ofSize: 20)) }

    func heading(_ string: String) {
        ensureRoom(40)
        text(string, font: .boldSystemFont(ofSize: 13))
        y += 2
    }

    func text(_ string: String, font: UIFont, color: UIColor = .black) {
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let height = ceil((string as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: .usesLineFragmentOrigin, attributes: attrs, context: nil).height)
        ensureRoom(height)
        (string as NSString).draw(in: CGRect(x: margin, y: y, width: width, height: height), withAttributes: attrs)
        y += height + 4
    }

    /// A table row. Two-column rows put the value on the right; wider rows split the width evenly.
    func row(_ cells: [String], header: Bool = false, bold: Bool = false, columns: Int = 2) {
        let font: UIFont = header || bold ? .boldSystemFont(ofSize: 9.5) : .systemFont(ofSize: 9.5)
        let rowHeight: CGFloat = 15
        ensureRoom(rowHeight)
        let columnWidth = width / CGFloat(columns)
        for (i, cell) in cells.enumerated() {
            let isLast = i == cells.count - 1
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = isLast && i > 0 ? .right : .left
            paragraph.lineBreakMode = .byTruncatingTail
            let x = columns == 2 ? (i == 0 ? margin : margin + width / 2) : margin + columnWidth * CGFloat(i)
            let w = columns == 2 ? width / 2 : columnWidth - 4
            (cell as NSString).draw(in: CGRect(x: x, y: y, width: w, height: rowHeight),
                                    withAttributes: [.font: font, .foregroundColor: UIColor.black,
                                                     .paragraphStyle: paragraph])
        }
        y += rowHeight
        if header {
            let line = UIBezierPath()
            line.move(to: CGPoint(x: margin, y: y - 2))
            line.addLine(to: CGPoint(x: margin + width, y: y - 2))
            UIColor.lightGray.setStroke()
            line.lineWidth = 0.5
            line.stroke()
        }
    }
}

extension ReportPDF {
    /// Writes the report to a temporary file for sharing.
    static func writeFile(year: Int, data: Data) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("gig-log-tax-report-\(year).pdf")
        do {
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }
}
