import SwiftUI
import Charts

/// Earnings per hour by day of week, time of day and platform, so you can see when it pays to drive.
/// Each shift counts toward the day and time block it started in.
struct InsightsView: View {
    let shifts: [Shift]

    var body: some View {
        List {
            if shifts.isEmpty {
                Text("Log a few shifts to see your best times.").foregroundStyle(.secondary)
            } else {
                Section {
                    chart(rates(by: weekdayLabel, order: weekdayOrder))
                } header: {
                    Text("Earnings per hour by day")
                }
                Section {
                    chart(rates(by: { TimeBlock(for: $0.start).rawValue },
                                order: TimeBlock.allCases.map(\.rawValue)))
                } header: {
                    Text("Earnings per hour by time of day")
                } footer: {
                    Text(TimeBlock.allCases.map { "\($0.rawValue): \($0.hours)" }.joined(separator: " · "))
                }
                Section("By platform") {
                    ForEach(platformStats, id: \.name) { stat in
                        LabeledContent(stat.name) {
                            VStack(alignment: .trailing) {
                                Text("\(stat.perHour.currency)/h").monospacedDigit()
                                Text("\(stat.perMile.currency)/mi").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Best times to drive")
    }

    // MARK: - Data

    struct Rate: Identifiable {
        let label: String
        let perHour: Double
        let hours: Double
        var id: String { label }
    }

    private func rates(by key: (Shift) -> String, order: [String]) -> [Rate] {
        let groups = Dictionary(grouping: shifts, by: key)
        return order.compactMap { label in
            guard let group = groups[label] else { return nil }
            let t = Totals(group)
            guard t.hours > 0 else { return nil }
            return Rate(label: label, perHour: t.income / t.hours, hours: t.hours)
        }
    }

    private var platformStats: [(name: String, perHour: Double, perMile: Double)] {
        Dictionary(grouping: shifts, by: \.platform)
            .map { name, group in
                let t = Totals(group)
                return (name, t.hours > 0 ? t.income / t.hours : 0, t.miles > 0 ? t.income / t.miles : 0)
            }
            .sorted { $0.perHour > $1.perHour }
    }

    private var weekdayOrder: [String] { Calendar.current.shortWeekdaySymbols }

    private func weekdayLabel(_ shift: Shift) -> String {
        Calendar.current.shortWeekdaySymbols[Calendar.current.component(.weekday, from: shift.start) - 1]
    }

    private func chart(_ data: [Rate]) -> some View {
        let best = data.max { $0.perHour < $1.perHour }?.label
        return Chart(data) { rate in
            BarMark(x: .value("Period", rate.label), y: .value("$ per hour", rate.perHour))
                .foregroundStyle(rate.label == best ? Color.accentColor : Color.accentColor.opacity(0.45))
                .annotation(position: .top) {
                    Text(rate.perHour.formatted(.currency(code: "USD").precision(.fractionLength(0))))
                        .font(.caption2).foregroundStyle(.secondary)
                }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let v = value.as(Double.self) { Text("$\(Int(v))") }
                }
            }
        }
        .frame(height: 200)
        .padding(.vertical, 8)
    }
}

enum TimeBlock: String, CaseIterable {
    case morning = "Morning", lunch = "Lunch", afternoon = "Afternoon", dinner = "Dinner", late = "Late"

    init(for date: Date) {
        switch Calendar.current.component(.hour, from: date) {
        case 5..<11: self = .morning
        case 11..<14: self = .lunch
        case 14..<17: self = .afternoon
        case 17..<21: self = .dinner
        default: self = .late
        }
    }

    var hours: String {
        switch self {
        case .morning: "5–11am"
        case .lunch: "11am–2pm"
        case .afternoon: "2–5pm"
        case .dinner: "5–9pm"
        case .late: "9pm–5am"
        }
    }
}
