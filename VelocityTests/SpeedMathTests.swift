import XCTest
@testable import Velocity
final class SpeedMathTests: XCTestCase {
    func testUnitConversions() {
        XCTAssertEqual(SpeedMath.display(10, mph: false), 36, accuracy: 0.001)
        XCTAssertEqual(SpeedMath.display(10, mph: true), 22.36936, accuracy: 0.001)
    }
    func testRejectsStaleAndUnknownMeasurements() {
        XCTAssertTrue(SpeedMath.valid(speed: 20, accuracy: 5, speedAccuracy: 1, age: 1))
        XCTAssertFalse(SpeedMath.valid(speed: -1, accuracy: 5, speedAccuracy: 1, age: 1))
        XCTAssertFalse(SpeedMath.valid(speed: 20, accuracy: 5, speedAccuracy: -1, age: 1))
        XCTAssertFalse(SpeedMath.valid(speed: 20, accuracy: 5, speedAccuracy: 1, age: 6))
        XCTAssertFalse(SpeedMath.valid(speed: .nan, accuracy: 5, speedAccuracy: 1, age: 1))
    }
    func testRejectsTeleportAndTimeGaps() {
        XCTAssertTrue(SpeedMath.distanceAllowed(distance: 22, interval: 1, speed: 22))
        XCTAssertFalse(SpeedMath.distanceAllowed(distance: 1000, interval: 1, speed: 22))
        XCTAssertFalse(SpeedMath.distanceAllowed(distance: 22, interval: 10, speed: 22))
        XCTAssertFalse(SpeedMath.distanceAllowed(distance: 22, interval: -1, speed: 22))
    }
}
