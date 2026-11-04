import CoreLocation
import Testing
@testable import GigLog

@Suite("GPS distance filtering")
struct DistanceFilterTests {
    @Test("The first good fix starts the measurement")
    func firstFix() {
        var filter = DistanceFilter()
        #expect(filter.accept(fix(metersNorth: 0, seconds: 0)) == .first)
    }

    @Test("Inaccurate fixes are ignored")
    func inaccurate() {
        var filter = DistanceFilter()
        #expect(filter.accept(fix(metersNorth: 0, seconds: 0, accuracy: 120)) == .ignored)
        #expect(filter.accept(fix(metersNorth: 0, seconds: 0, accuracy: -1)) == .ignored)
        #expect(filter.last == nil)
    }

    @Test("Normal driving adds the distance in miles")
    func driving() throws {
        var filter = DistanceFilter()
        _ = filter.accept(fix(metersNorth: 0, seconds: 0))
        let result = filter.accept(fix(metersNorth: 1609.344, seconds: 120))   // 1 mile in 2 minutes
        guard case .moved(let miles) = result else {
            Issue.record("Expected movement, got \(result)")
            return
        }
        #expect(isClose(miles, 1, tolerance: 0.01))
    }

    @Test("Small moves while parked are ignored but still add up later")
    func parkedDrift() throws {
        var filter = DistanceFilter()
        _ = filter.accept(fix(metersNorth: 0, seconds: 0))
        #expect(filter.accept(fix(metersNorth: 4, seconds: 10)) == .ignored)
        #expect(filter.accept(fix(metersNorth: 8, seconds: 20)) == .ignored)
        guard case .moved(let miles) = filter.accept(fix(metersNorth: 30, seconds: 30)) else {
            Issue.record("Expected movement after slow progress")
            return
        }
        #expect(isClose(miles * DistanceFilter.metersPerMile, 30, tolerance: 0.5))
    }

    @Test("A single impossible jump is rejected without losing the next real move")
    func jump() throws {
        var filter = DistanceFilter()
        _ = filter.accept(fix(metersNorth: 0, seconds: 0))
        #expect(filter.accept(fix(metersNorth: 5_000, seconds: 5)) == .rejectedJump)   // 1000 m/s
        guard case .moved(let miles) = filter.accept(fix(metersNorth: 100, seconds: 10)) else {
            Issue.record("Expected the next real fix to count")
            return
        }
        #expect(isClose(miles * DistanceFilter.metersPerMile, 100, tolerance: 0.5))
    }

    @Test("After repeated jumps the filter re-anchors instead of getting stuck")
    func reanchor() {
        var filter = DistanceFilter()
        _ = filter.accept(fix(metersNorth: 0, seconds: 0))
        for i in 1...3 {
            #expect(filter.accept(fix(metersNorth: 50_000, seconds: Double(i))) == .rejectedJump)
        }
        guard case .moved = filter.accept(fix(metersNorth: 50_100, seconds: 20)) else {
            Issue.record("Expected movement from the new anchor")
            return
        }
    }

    @Test("Out-of-order fixes are ignored")
    func outOfOrder() {
        var filter = DistanceFilter()
        _ = filter.accept(fix(metersNorth: 0, seconds: 100))
        #expect(filter.accept(fix(metersNorth: 200, seconds: 50)) == .ignored)
    }
}
