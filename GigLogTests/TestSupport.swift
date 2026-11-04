// swiftlint:disable force_unwrapping
import CoreLocation
import Foundation
import SwiftData
@testable import GigLog

/// Containers made for tests, kept alive for the whole test run so their models stay valid.
@MainActor private var testContainers: [ModelContainer] = []

/// An empty in-memory store, so tests never touch the app's real data.
@MainActor
func makeTestContext() throws -> ModelContext {
    let schema = Schema(versionedSchema: GigLogSchemaV1.self)
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: config)
    testContainers.append(container)
    return container.mainContext
}

func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
    Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
}

func isClose(_ a: Double, _ b: Double, tolerance: Double = 0.000_1) -> Bool {
    abs(a - b) <= tolerance
}

/// A fix `metersNorth` north of a fixed start point, `seconds` after a fixed start time.
func fix(metersNorth: Double, seconds: TimeInterval, accuracy: Double = 5) -> CLLocation {
    let start = CLLocationCoordinate2D(latitude: 37.0, longitude: -122.0)
    let latitude = start.latitude + metersNorth / 111_320
    return CLLocation(coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: start.longitude),
                      altitude: 0, horizontalAccuracy: accuracy, verticalAccuracy: 5,
                      timestamp: Date(timeIntervalSince1970: 1_800_000_000 + seconds))
}
