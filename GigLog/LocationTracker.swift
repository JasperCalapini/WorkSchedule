import CoreLocation
import Observation

/// Counts miles driven during the active shift using GPS, including while the app is in the background.
@MainActor
@Observable
final class LocationTracker: NSObject, CLLocationManagerDelegate {
    static let shared = LocationTracker()

    private(set) var authorization: CLAuthorizationStatus = .notDetermined
    private(set) var shift: Shift?
    var isTracking: Bool { shift != nil }
    var isDenied: Bool { authorization == .denied || authorization == .restricted }

    private let manager = CLLocationManager()
    private var backgroundSession: CLBackgroundActivitySession?
    private var lastLocation: CLLocation?
    /// Route points not yet written to the shift (saved in batches to avoid constant rewrites).
    private var pendingPoints: [RoutePoint] = []
    private var recordsRoute: Bool { UserDefaults.standard.object(forKey: "recordRoute") as? Bool ?? true }

    private static let metersPerMile = 1609.344
    private static let maxAccuracy = 50.0      // ignore fixes worse than 50 m
    private static let maxSpeed = 60.0         // m/s (~134 mph); faster means a GPS jump

    override init() {
        super.init()
        manager.delegate = self
        manager.activityType = .automotiveNavigation
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 10
        manager.pausesLocationUpdatesAutomatically = false
        authorization = manager.authorizationStatus
    }

    func start(for shift: Shift) {
        self.shift = shift
        lastLocation = nil
        if shift.gpsMiles == nil { shift.gpsMiles = 0 }
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
        backgroundSession = CLBackgroundActivitySession()
        manager.startUpdatingLocation()
    }

    func stop() {
        flushRoute()
        manager.stopUpdatingLocation()
        backgroundSession?.invalidate()
        backgroundSession = nil
        shift = nil
        lastLocation = nil
    }

    private func handle(_ locations: [CLLocation]) {
        guard let shift else { return }
        for location in locations {
            guard location.horizontalAccuracy >= 0, location.horizontalAccuracy <= Self.maxAccuracy else { continue }
            guard let last = lastLocation else {
                lastLocation = location
                record(location, personal: shift.isPersonal)
                continue
            }
            let meters = location.distance(from: last)
            // Skip GPS drift while parked; keep the old point so slow movement still adds up.
            if meters < max(10, location.horizontalAccuracy) { continue }
            let seconds = location.timestamp.timeIntervalSince(last.timestamp)
            if seconds > 0 && meters / seconds <= Self.maxSpeed {
                let miles = meters / Self.metersPerMile
                if shift.isPersonal {
                    shift.personalGPSMiles += miles
                } else {
                    shift.gpsMiles = (shift.gpsMiles ?? 0) + miles
                }
                record(location, personal: shift.isPersonal)
            }
            lastLocation = location
        }
    }

    private func record(_ location: CLLocation, personal: Bool) {
        guard recordsRoute else { return }
        pendingPoints.append(RoutePoint(location, isPersonal: personal))
        if pendingPoints.count >= 20 { flushRoute() }
    }

    private func flushRoute() {
        guard let shift, !pendingPoints.isEmpty else { return }
        shift.routeData = (shift.routeData ?? Data()) + RoutePoint.encode(pendingPoints)
        pendingPoints.removeAll()
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in self.handle(locations) }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in self.authorization = status }
    }
}
