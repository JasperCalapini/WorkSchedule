import CoreLocation
import Observation

/// Decides how much distance each GPS fix adds. Kept free of CoreLocation callbacks
/// and app state so it can be unit tested.
struct DistanceFilter {
    static let metersPerMile = 1609.344

    enum Result: Equatable {
        /// Too inaccurate, too close to the last point (parked drift), or out of order.
        case ignored
        /// The first usable fix; it starts the measurement.
        case first
        /// Real movement of this many miles.
        case moved(miles: Double)
        /// An impossible jump (faster than `maxSpeed`), usually a bad fix.
        case rejectedJump
    }

    var maxAccuracy = 50.0      // meters; ignore worse fixes
    var maxSpeed = 60.0         // m/s (~134 mph); faster means a GPS jump
    var minimumStep = 10.0      // meters; smaller moves are drift while parked
    /// After this many jumps in a row, the last good point was probably the bad one,
    /// so start measuring again from the new position.
    var jumpsBeforeReanchor = 3

    private(set) var last: CLLocation?
    private var consecutiveJumps = 0

    mutating func accept(_ location: CLLocation) -> Result {
        guard location.horizontalAccuracy >= 0, location.horizontalAccuracy <= maxAccuracy else { return .ignored }
        guard let last else {
            self.last = location
            return .first
        }
        let seconds = location.timestamp.timeIntervalSince(last.timestamp)
        guard seconds > 0 else { return .ignored }
        let meters = location.distance(from: last)
        // Keep the old point so slow movement still adds up.
        if meters < max(minimumStep, location.horizontalAccuracy) { return .ignored }

        if meters / seconds > maxSpeed {
            consecutiveJumps += 1
            if consecutiveJumps >= jumpsBeforeReanchor {
                self.last = location
                consecutiveJumps = 0
            }
            return .rejectedJump
        }
        consecutiveJumps = 0
        self.last = location
        return .moved(miles: meters / Self.metersPerMile)
    }

    mutating func reset() {
        last = nil
        consecutiveJumps = 0
    }
}

/// Counts miles driven during the active shift using GPS, including while the app is in the
/// background. Uses `CLLocationUpdate.liveUpdates` with a `CLBackgroundActivitySession`, which
/// lets iOS relaunch the app to continue a shift if the system closed it.
@MainActor
@Observable
final class LocationTracker: NSObject, CLLocationManagerDelegate {
    static let shared = LocationTracker()

    /// If no GPS point was recorded for this long before tracking resumed, the shift is
    /// flagged as interrupted.
    static let interruptionThreshold: TimeInterval = 180
    private static let saveEvery = 20

    private(set) var authorization: CLAuthorizationStatus = .notDetermined
    private(set) var shift: Shift?
    var isTracking: Bool { shift != nil }
    var isDenied: Bool { authorization == .denied || authorization == .restricted }

    // Only used for the permission prompt and authorization changes.
    private let manager = CLLocationManager()
    @ObservationIgnored private var backgroundSession: CLBackgroundActivitySession?
    @ObservationIgnored private var updatesTask: Task<Void, Never>?
    @ObservationIgnored private var filter = DistanceFilter()
    /// Route points not yet written to the shift (saved in batches to avoid constant rewrites).
    @ObservationIgnored private var pendingPoints: [RoutePoint] = []
    @ObservationIgnored private var changesSinceSave = 0

    override init() {
        super.init()
        manager.delegate = self
        authorization = manager.authorizationStatus
    }

    func start(for shift: Shift) {
        stopUpdates()
        self.shift = shift
        filter.reset()
        if shift.gpsMiles == nil { shift.gpsMiles = 0 }
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        backgroundSession = CLBackgroundActivitySession()
        updatesTask = Task { [weak self] in
            do {
                for try await update in CLLocationUpdate.liveUpdates(.automotiveNavigation) {
                    guard let self, !Task.isCancelled else { return }
                    if let location = update.location { self.handle(location) }
                }
            } catch {
                Log.location.error("Location updates ended: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Continues a shift after the app was relaunched, and flags it if GPS was off for a while.
    func resume(_ shift: Shift) {
        let lastRecorded = RoutePoint.last(in: shift.routeData)?.date ?? shift.start
        if Date.now.timeIntervalSince(lastRecorded) > Self.interruptionThreshold {
            shift.gpsInterrupted = true
            Log.location.notice("Resumed a shift after a GPS gap")
        }
        start(for: shift)
    }

    func stop() {
        flush()
        stopUpdates()
        shift = nil
        filter.reset()
    }

    private func stopUpdates() {
        updatesTask?.cancel()
        updatesTask = nil
        backgroundSession?.invalidate()
        backgroundSession = nil
    }

    private func handle(_ location: CLLocation) {
        guard let shift else { return }
        switch filter.accept(location) {
        case .first:
            record(location, in: shift)
        case .moved(let miles):
            if shift.isPersonal {
                shift.personalGPSMiles += miles
            } else {
                shift.gpsMiles = (shift.gpsMiles ?? 0) + miles
            }
            record(location, in: shift)
        case .ignored, .rejectedJump:
            break
        }
        LiveActivityController.update(for: shift)
    }

    private func record(_ location: CLLocation, in shift: Shift) {
        if SettingsKey.flag(SettingsKey.recordRoute) {
            pendingPoints.append(RoutePoint(location, isPersonal: shift.isPersonal))
        }
        changesSinceSave += 1
        if changesSinceSave >= Self.saveEvery { flush() }
    }

    /// Writes buffered route points and saves miles, so a crash loses at most a few points.
    private func flush() {
        guard let shift else { return }
        if !pendingPoints.isEmpty {
            shift.routeData = (shift.routeData ?? Data()) + RoutePoint.encode(pendingPoints)
            shift.routePointCount += pendingPoints.count
            pendingPoints.removeAll()
        }
        changesSinceSave = 0
        AppData.save("GPS progress")
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in self.authorization = status }
    }
}
