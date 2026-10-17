import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

@main
struct GigLogWidgets: WidgetBundle {
    var body: some Widget {
        ShiftLiveActivity()
    }
}

private let teal = Color(red: 0.059, green: 0.463, blue: 0.431)
private let lightTeal = Color(red: 0.176, green: 0.831, blue: 0.749)

/// Shift timer, miles and the errand button on the Lock Screen and in the Dynamic Island.
struct ShiftLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ShiftActivityAttributes.self) { context in
            LockScreenView(context: context)
                .padding()
                .activityBackgroundTint(Color.black.opacity(0.75))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.attributes.platform, systemImage: modeSymbol(context.state))
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.startDate, style: .timer)
                        .monospacedDigit()
                        .multilineTextAlignment(.trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        MilesView(state: context.state)
                        Spacer()
                        ErrandButton(isPersonal: context.state.isPersonal)
                    }
                }
            } compactLeading: {
                Image(systemName: modeSymbol(context.state))
                    .foregroundStyle(context.state.isPersonal ? .orange : lightTeal)
            } compactTrailing: {
                Text(miles(context.state.businessMiles))
                    .monospacedDigit()
            } minimal: {
                Image(systemName: modeSymbol(context.state))
                    .foregroundStyle(context.state.isPersonal ? .orange : lightTeal)
            }
        }
    }
}

private struct LockScreenView: View {
    let context: ActivityViewContext<ShiftActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(context.attributes.platform, systemImage: modeSymbol(context.state))
                    .font(.headline)
                Spacer()
                Text(context.state.startDate, style: .timer)
                    .font(.title2.monospacedDigit().weight(.semibold))
                    .multilineTextAlignment(.trailing)
            }
            if context.state.isPersonal {
                Text("Personal errand — not counting as business")
                    .font(.caption).foregroundStyle(.orange)
            }
            HStack {
                MilesView(state: context.state)
                Spacer()
                ErrandButton(isPersonal: context.state.isPersonal)
            }
        }
        .foregroundStyle(.white)
    }
}

private struct MilesView: View {
    let state: ShiftActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(miles(state.businessMiles)) business")
                .font(.headline.monospacedDigit())
                .foregroundStyle(lightTeal)
            if state.personalMiles > 0 {
                Text("\(miles(state.personalMiles)) personal")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.orange)
            }
        }
    }
}

private struct ErrandButton: View {
    let isPersonal: Bool

    var body: some View {
        Button(intent: ToggleErrandIntent()) {
            Label(isPersonal ? "Back to work" : "Errand", systemImage: isPersonal ? "car.fill" : "cart")
                .font(.subheadline.weight(.semibold))
        }
        .tint(isPersonal ? teal : .orange)
    }
}

private func modeSymbol(_ state: ShiftActivityAttributes.ContentState) -> String {
    state.isPersonal ? "cart.fill" : "car.fill"
}

private func miles(_ value: Double) -> String {
    value.formatted(.number.precision(.fractionLength(1))) + " mi"
}
