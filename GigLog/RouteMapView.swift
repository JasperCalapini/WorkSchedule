import SwiftUI
import MapKit
import CoreLocation

/// One recorded GPS point. Stored compactly as 32 bytes (latitude, longitude, time, personal flag).
struct RoutePoint {
    var latitude: Double
    var longitude: Double
    var time: TimeInterval
    /// Driven in personal mode (errand), so not business miles.
    var isPersonal: Bool

    init(latitude: Double, longitude: Double, time: TimeInterval, isPersonal: Bool) {
        self.latitude = latitude
        self.longitude = longitude
        self.time = time
        self.isPersonal = isPersonal
    }

    init(_ location: CLLocation, isPersonal: Bool) {
        self.init(latitude: location.coordinate.latitude,
                  longitude: location.coordinate.longitude,
                  time: location.timestamp.timeIntervalSince1970,
                  isPersonal: isPersonal)
    }

    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
    var date: Date { Date(timeIntervalSince1970: time) }

    private static let size = 32

    static func encode(_ points: [RoutePoint]) -> Data {
        var data = Data(capacity: points.count * size)
        for p in points {
            for value in [p.latitude, p.longitude, p.time, p.isPersonal ? 1 : 0] {
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
                                     time: value(at: offset + 16),
                                     isPersonal: value(at: offset + 24) != 0))
            offset += size
        }
        return points
    }
}

/// A continuous stretch of the route driven in one mode.
struct RouteSegment: Identifiable {
    let id: Int
    let isPersonal: Bool
    let coordinates: [CLLocationCoordinate2D]

    /// Splits points into business / personal runs. Each run starts at the previous run's
    /// last point so the line stays connected.
    static func split(_ points: [RoutePoint]) -> [RouteSegment] {
        var segments: [RouteSegment] = []
        var current: [CLLocationCoordinate2D] = []
        var mode = points.first?.isPersonal ?? false
        for point in points {
            if point.isPersonal != mode {
                segments.append(RouteSegment(id: segments.count, isPersonal: mode, coordinates: current))
                current = current.last.map { [$0] } ?? []
                mode = point.isPersonal
            }
            current.append(point.coordinate)
        }
        if !current.isEmpty {
            segments.append(RouteSegment(id: segments.count, isPersonal: mode, coordinates: current))
        }
        return segments
    }
}

extension Shift {
    var route: [RoutePoint] { RoutePoint.decode(routeData) }
    var hasRoute: Bool { (routeData?.count ?? 0) >= 64 }
}

enum RouteStyle {
    static let business = Color.accentColor
    static let personal = Color.orange
}

/// The route drawn as lines (business solid, personal dashed orange) with start and end markers.
struct RouteMap: View {
    let points: [RoutePoint]
    var interactive = true

    var body: some View {
        let segments = RouteSegment.split(points)
        Map(initialPosition: .automatic, interactionModes: interactive ? .all : []) {
            ForEach(segments) { segment in
                MapPolyline(coordinates: segment.coordinates)
                    .stroke(segment.isPersonal ? RouteStyle.personal : RouteStyle.business,
                            style: StrokeStyle(lineWidth: 5, lineCap: .round,
                                               dash: segment.isPersonal ? [8, 8] : []))
            }
            if let first = points.first {
                Marker("Start", systemImage: "flag.fill", coordinate: first.coordinate)
                    .tint(.green)
            }
            if points.count > 1, let last = points.last {
                Marker("End", systemImage: "flag.checkered", coordinate: last.coordinate)
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
                    HStack(spacing: 16) {
                        legend("Business", color: RouteStyle.business, dashed: false)
                        legend("Personal", color: RouteStyle.personal, dashed: true)
                    }
                    .font(.caption)
                    Grid(alignment: .leading, horizontalSpacing: 16) {
                        GridRow {
                            stat("Business GPS", (shift.gpsMiles ?? 0).oneDecimal)
                            stat("Personal GPS", shift.personalGPSMiles.oneDecimal)
                            stat("Time", duration)
                        }
                        GridRow {
                            stat("Started", shift.start.formatted(date: .omitted, time: .shortened))
                            stat("Ended", shift.end?.formatted(date: .omitted, time: .shortened) ?? "In progress")
                            stat("Business mi", shift.miles.oneDecimal)
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

    private func legend(_ label: String, color: Color, dashed: Bool) -> some View {
        HStack(spacing: 6) {
            Path { path in
                path.move(to: CGPoint(x: 2, y: 2))
                path.addLine(to: CGPoint(x: 22, y: 2))
            }
            .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: dashed ? [4, 6] : []))
            .frame(width: 24, height: 4)
            Text(label)
        }
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
