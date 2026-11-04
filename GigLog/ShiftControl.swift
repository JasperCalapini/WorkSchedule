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
        AppData.save("start shift")
        if SettingsKey.flag(SettingsKey.useGPS) {
            LocationTracker.shared.start(for: shift)
        }
        LiveActivityController.start(for: shift)
        return shift
    }

    /// Picks up a shift that was running when the app was closed or relaunched.
    static func resumeIfNeeded() {
        guard let active = AppData.activeShift() else {
            LiveActivityController.end()   // clean up a stale Lock Screen display
            return
        }
        let tracker = LocationTracker.shared
        if !tracker.isTracking && active.gpsMiles != nil {
            tracker.resume(active)
        }
        LiveActivityController.start(for: active)
    }

    /// Personal errand ↔ back to work for the running shift.
    static func toggleErrand() {
        guard let shift = AppData.activeShift() else { return }
        shift.isPersonal.toggle()
        AppData.save("toggle errand")
        LiveActivityController.update(for: shift, force: true)
    }

    /// Call after the running shift has been ended (its end time set).
    static func finished() {
        LocationTracker.shared.stop()
        LiveActivityController.end()
        AppData.save("end shift")
    }

    /// Deletes the running shift and stops tracking it.
    static func discard(_ shift: Shift) {
        LocationTracker.shared.stop()
        LiveActivityController.end()
        AppData.context.delete(shift)
        AppData.save("discard shift")
    }
}

/// Keeps the Lock Screen / Dynamic Island in sync with the running shift.
@MainActor
enum LiveActivityController {
    /// If no update arrives within this time, the Lock Screen shows the shift as not updating
    /// (for example because the app was swiped away).
    static let staleAfter: TimeInterval = 5 * 60
    private static var lastUpdate = Date.distantPast

    private static var current: Activity<ShiftActivityAttributes>? {
        Activity<ShiftActivityAttributes>.activities.first
    }

    static func start(for shift: Shift) {
        if let activity = current {
            if activity.attributes.platform == shift.platform {
                update(for: shift, force: true)
                return
            }
            end()   // left over from a different shift
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        do {
            _ = try Activity.request(attributes: ShiftActivityAttributes(platform: shift.platform),
                                     content: content(for: shift))
        } catch {
            Log.data.error("Live Activity not started: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Updates at most every 15 seconds unless forced (Apple limits how often activities refresh).
    static func update(for shift: Shift, force: Bool = false) {
        guard let activity = current else { return }
        guard force || Date.now.timeIntervalSince(lastUpdate) >= 15 else { return }
        lastUpdate = .now
        let content = content(for: shift)
        Task { await activity.update(content) }
    }

    static func end() {
        for activity in Activity<ShiftActivityAttributes>.activities {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }

    private static func content(for shift: Shift) -> ActivityContent<ShiftActivityAttributes.ContentState> {
        let state = ShiftActivityAttributes.ContentState(
            startDate: shift.start, businessMiles: shift.gpsMiles ?? 0,
            personalMiles: shift.personalGPSMiles, isPersonal: shift.isPersonal)
        return ActivityContent(state: state, staleDate: Date.now.addingTimeInterval(staleAfter))
    }
}

// MARK: - Shortcuts

enum ShortcutError: Error, CustomLocalizedStringResourceConvertible {
    case dataUnavailable

    var localizedStringResource: LocalizedStringResource {
        "Gig Log couldn't open its data. Open the app for details."
    }
}

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
        guard AppData.loadError == nil else { throw ShortcutError.dataUnavailable }
        if let active = AppData.activeShift() {
            return .result(dialog: "Your \(active.platform) shift is already running.")
        }
        let name = matchingPlatform(platform)
        ShiftControl.start(platform: name)
        return .result(dialog: "Started your \(name) shift.")
    }

    /// Uses the saved spelling of a platform ("doordash" → "DoorDash") so totals group correctly.
    @MainActor
    private func matchingPlatform(_ typed: String) -> String {
        let trimmed = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        let saved = (try? AppData.context.fetch(FetchDescriptor<Platform>())) ?? []
        return saved.first { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }?.name ?? trimmed
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
