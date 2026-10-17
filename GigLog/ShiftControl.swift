import ActivityKit
import AppIntents
import Foundation
import SwiftData

/// Starting, switching and finishing shifts, shared by the screens, Shortcuts and the Lock Screen.
@MainActor
enum ShiftControl {
    @discardableResult
    static func start(platform: String, odometer: Double? = nil, photo: Data? = nil) -> Shift {
        let shift = Shift(platform: platform, odometerStart: odometer)
        shift.odometerStartPhoto = photo
        AppData.context.insert(shift)
        try? AppData.context.save()
        if UserDefaults.standard.object(forKey: "useGPS") as? Bool ?? true {
            LocationTracker.shared.start(for: shift)
        }
        LiveActivityController.start(for: shift)
        return shift
    }

    /// Personal errand ↔ back to work for the running shift.
    static func toggleErrand() {
        guard let shift = AppData.activeShift() else { return }
        shift.isPersonal.toggle()
        try? AppData.context.save()
        LiveActivityController.update(for: shift, force: true)
    }

    /// Call after a shift is ended or discarded.
    static func finished() {
        LocationTracker.shared.stop()
        LiveActivityController.end()
    }
}

/// Keeps the Lock Screen / Dynamic Island in sync with the running shift.
@MainActor
enum LiveActivityController {
    private static var lastUpdate = Date.distantPast

    private static var current: Activity<ShiftActivityAttributes>? {
        Activity<ShiftActivityAttributes>.activities.first
    }

    static func start(for shift: Shift) {
        guard current == nil else {
            update(for: shift, force: true)
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        _ = try? Activity.request(attributes: ShiftActivityAttributes(platform: shift.platform),
                                  content: ActivityContent(state: state(for: shift), staleDate: nil))
    }

    /// Updates at most every 15 seconds unless forced (Apple limits how often activities refresh).
    static func update(for shift: Shift, force: Bool = false) {
        guard let activity = current else { return }
        guard force || Date.now.timeIntervalSince(lastUpdate) >= 15 else { return }
        lastUpdate = .now
        let content = ActivityContent(state: state(for: shift), staleDate: nil)
        Task { await activity.update(content) }
    }

    static func end() {
        for activity in Activity<ShiftActivityAttributes>.activities {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }

    private static func state(for shift: Shift) -> ShiftActivityAttributes.ContentState {
        .init(startDate: shift.start, businessMiles: shift.gpsMiles ?? 0,
              personalMiles: shift.personalGPSMiles, isPersonal: shift.isPersonal)
    }
}

// MARK: - Shortcuts

/// "Start Shift" action for the Shortcuts app, e.g. an automation that runs when DoorDash opens.
struct StartShiftIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Shift"
    static var description = IntentDescription("Starts a Gig Log shift with GPS mileage tracking.")
    // Location tracking and the Lock Screen display can only start while the app is open.
    static var openAppWhenRun = true

    @Parameter(title: "Platform", default: "DoorDash")
    var platform: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        if let active = AppData.activeShift() {
            return .result(dialog: "Your \(active.platform) shift is already running.")
        }
        ShiftControl.start(platform: platform)
        return .result(dialog: "Started your \(platform) shift.")
    }
}

struct GigLogShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: StartShiftIntent(),
                    phrases: ["Start a shift in \(.applicationName)", "Start \(.applicationName)"],
                    shortTitle: "Start Shift",
                    systemImageName: "car.fill")
        AppShortcut(intent: ToggleErrandIntent(),
                    phrases: ["Personal errand in \(.applicationName)"],
                    shortTitle: "Personal Errand",
                    systemImageName: "cart")
    }
}
