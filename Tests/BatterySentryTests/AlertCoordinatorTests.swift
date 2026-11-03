import XCTest
@testable import BatterySentry

@MainActor
final class AlertCoordinatorTests: XCTestCase {
    func testSevereRepeatSnoozeAndAcknowledge() {
        let suite = "BatterySentryTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = AppSettings(defaults: defaults)
        var current = Date(timeIntervalSince1970: 1_000_000)
        var deliveries: [Int] = []
        let alerts = AlertCoordinator(subsystem: "BatterySentryTests", now: { current }) { level, _, _ in
            deliveries.append(level)
        }

        alerts.evaluate(level: 20, hasExternalPower: false, settings: settings)
        XCTAssertEqual(deliveries, [20])
        current.addTimeInterval(600)
        alerts.evaluate(level: 15, hasExternalPower: false, settings: settings)
        XCTAssertEqual(deliveries, [20])
        alerts.evaluate(level: 10, hasExternalPower: false, settings: settings)
        XCTAssertEqual(deliveries, [20, 10])

        alerts.snooze()
        current.addTimeInterval(1_799)
        alerts.evaluate(level: 9, hasExternalPower: false, settings: settings)
        XCTAssertEqual(deliveries, [20, 10])
        current.addTimeInterval(1)
        alerts.evaluate(level: 9, hasExternalPower: false, settings: settings)
        XCTAssertEqual(deliveries, [20, 10, 9])

        alerts.acknowledge()
        current.addTimeInterval(3_600)
        alerts.evaluate(level: 8, hasExternalPower: false, settings: settings)
        XCTAssertEqual(deliveries, [20, 10, 9])
        alerts.evaluate(level: 8, hasExternalPower: true, settings: settings)
        current.addTimeInterval(100)
        alerts.evaluate(level: 8, hasExternalPower: false, settings: settings)
        XCTAssertEqual(deliveries, [20, 10, 9, 8])
    }
}
