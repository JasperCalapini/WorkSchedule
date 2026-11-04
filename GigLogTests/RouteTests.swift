import CoreLocation
import Foundation
import Testing
@testable import GigLog

@Suite("Route storage and drawing")
struct RouteTests {
    private func points(_ modes: [Bool]) -> [RoutePoint] {
        modes.enumerated().map { i, personal in
            RoutePoint(latitude: 37 + Double(i) * 0.001, longitude: -122, time: Double(i) * 10, isPersonal: personal)
        }
    }

    @Test("Points survive encoding and decoding exactly")
    func roundTrip() {
        let original = points([false, false, true, false])
        let decoded = RoutePoint.decode(RoutePoint.encode(original))
        #expect(decoded.count == original.count)
        for (a, b) in zip(original, decoded) {
            #expect(a.latitude == b.latitude)
            #expect(a.longitude == b.longitude)
            #expect(a.time == b.time)
            #expect(a.isPersonal == b.isPersonal)
        }
    }

    @Test("Appending batches gives the same result as encoding all at once")
    func appendBatches() {
        let all = points([false, true, true, false, false])
        let batched = RoutePoint.encode(Array(all[0..<2])) + RoutePoint.encode(Array(all[2...]))
        #expect(batched == RoutePoint.encode(all))
        #expect(RoutePoint.count(in: batched) == 5)
    }

    @Test("Empty, missing and truncated data decode safely")
    func badData() {
        #expect(RoutePoint.decode(nil).isEmpty)
        #expect(RoutePoint.decode(Data()).isEmpty)
        let truncated = RoutePoint.encode(points([false, false])).dropLast(5)
        #expect(RoutePoint.decode(Data(truncated)).count == 1)
        #expect(RoutePoint.last(in: nil) == nil)
    }

    @Test("The last point is read without decoding everything")
    func lastPoint() {
        let all = points([false, false, true])
        #expect(RoutePoint.last(in: RoutePoint.encode(all))?.time == all.last?.time)
    }

    @Test("Business and personal stretches become separate, connected segments")
    func segments() {
        let segments = RouteSegment.split(points([false, false, true, true, false]))
        #expect(segments.map(\.isPersonal) == [false, true, false])
        // Each new segment starts where the previous one ended.
        #expect(segments[0].coordinates.last?.latitude == segments[1].coordinates.first?.latitude)
        #expect(segments[1].coordinates.last?.latitude == segments[2].coordinates.first?.latitude)
        #expect(RouteSegment.split([]).isEmpty)
    }

    @Test("Simplifying keeps the ends, mode changes, and stays near the limit")
    func simplify() {
        var modes = Array(repeating: false, count: 1_000)
        modes[500] = true
        let all = points(modes)
        let simple = RoutePoint.simplified(all, maxPoints: 50)
        #expect(simple.first?.time == all.first?.time)
        #expect(simple.last?.time == all.last?.time)
        #expect(simple.count <= 54)
        #expect(simple.contains { $0.isPersonal })
        #expect(RoutePoint.simplified(Array(all.prefix(10)), maxPoints: 50).count == 10)
    }
}
