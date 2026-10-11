import SwiftUI
import MapKit
import CoreLocation

/// One recorded GPS point. Stored compactly as 24 bytes (latitude, longitude, time).
struct RoutePoint {
    var latitude: Double
    var longitude: Double
    var time: TimeInterval

    init(latitude: Double, longitude: Double, time: TimeInterval) {
        self.latitude = latitude
        self.longitude = longitude
        self.time = time
    }

    init(_ location: CLLocation) {
        self.init(latitude: location.coordinate.latitude,
                  longitude: location.coordinate.longitude,
                  time: location.timestamp.timeIntervalSince1970)
    }

    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
    var date: Date { Date(timeIntervalSince1970: time) }

    private static let size = 24

    static func encode(_ points: [RoutePoint]) -> Data {
        var data = Data(capacity: points.count * size)
        for p in points {
            for value in [p.latitude, p.longitude, p.time] {
                withUnsafeBytes(of: value.bitPattern.littleEndian) { data.append(contentsOf: $0) }
            }
        }
        return data
    }

    static func decode(_ data: Data?) -> [RoutePoint] {
        guard let data else { return [] }
        let bytes = [UInt8](data)
        func value(at offset: Int) -> Double {
            var bits: UInt64 = 0
            for i in 0..<8 { bits |= UInt64(bytes[offset + i]) << (8 * UInt64(i)) }
            return Double(bitPattern: bits)
        }
        var points: [RoutePoint] = []
        points.reserveCapacity(bytes.count / size)
        var offset = 0
        while offset + size <= bytes.count {
            points.append(RoutePoint(latitude: value(at: offset),
                                     longitude: value(at: offset + 8),
                                     time: value(at: offset + 16)))
            offset += size
        }
        return points
    }
}

extension Shift {
    var route: [RoutePoint] { RoutePoint.decode(routeData) }
    var hasRoute: Bool { (routeData?.count ?? 0) >= 48 }
}

/// The route drawn as a line with start and end markers.
struct RouteMap: View {
    let points: [RoutePoint]
    var interactive = true

    var body: some View {
        let coordinates = points.map(\.coordinate)
        Map(initialPosition: .automatic, interactionModes: interactive ? .all : []) {
            MapPolyline(coordinates: coordinates)
                .stroke(Color.accentColor, lineWidth: 5)
            if let first = coordinates.first {
                Marker("Start", systemImage: "flag.fill", coordinate: first)
                    .tint(.green)
            }
            if coordinates.count > 1, let last = coordinates.last {
                Marker("End", systemImage: "flag.checkered", coordinate: last)
                    .tint(.red)
            }
        }
        .mapControls {
            MapCompass()
            MapScaleView()
        }
    }
}

/// Full-screen route review with the shift's details, like a hiking app's activity view.
struct RouteDetailView: View {
    let shift: Shift

    var body: some View {
        let points = shift.route
        RouteMap(points: points)
            .ignoresSafeArea(edges: .bottom)
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("\(shift.platform) · \(shift.start.formatted(date: .abbreviated, time: .omitted))")
                        .font(.headline)
                    Grid(alignment: .leading, horizontalSpacing: 16) {
                        GridRow {
                            stat("GPS miles", (shift.gpsMiles ?? 0).oneDecimal)
                            stat("Business mi", shift.miles.oneDecimal)
                            stat("Time", duration)
                        }
                        GridRow {
                            stat("Started", shift.start.formatted(date: .omitted, time: .shortened))
                            stat("Ended", shift.end?.formatted(date: .omitted, time: .shortened) ?? "In progress")
                            stat("Points", String(points.count))
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                .padding()
            }
            .navigationTitle("Route")
            .navigationBarTitleDisplayMode(.inline)
    }

    private var duration: String {
        let seconds = (shift.end ?? .now).timeIntervalSince(shift.start)
        return Duration.seconds(max(0, seconds)).formatted(.units(allowed: [.hours, .minutes], width: .narrow))
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline).monospacedDigit()
        }
    }
}

/// A small non-interactive map that opens the full route when tapped.
struct RoutePreviewLink: View {
    let shift: Shift

    var body: some View {
        NavigationLink {
            RouteDetailView(shift: shift)
        } label: {
            RouteMap(points: shift.route, interactive: false)
                .frame(height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .allowsHitTesting(false)
        }
        .accessibilityLabel("View route on map")
    }
}
