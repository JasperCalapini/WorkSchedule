import ActivityKit
import AppIntents
import Foundation

/// Data shown on the Lock Screen / Dynamic Island while a shift is running.
/// This file is compiled into both the app and the widget extension.
struct ShiftActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var startDate: Date
        var businessMiles: Double
        var personalMiles: Double
        var isPersonal: Bool
    }

    var platform: String
}

/// The "Personal errand / Back to work" button on the Lock Screen.
/// Live Activity intents run inside the app, where ShiftControl does the real work;
/// the widget extension only has a stub so it can show the button.
struct ToggleErrandIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Personal Errand / Back to Work"
    static var description = IntentDescription("Switches the running shift between business and personal miles.")

    init() {}

    func perform() async throws -> some IntentResult {
        await ShiftControl.toggleErrand()
        return .result()
    }
}
