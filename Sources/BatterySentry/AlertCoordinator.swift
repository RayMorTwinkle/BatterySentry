import Foundation
import os.log

/// 一次放电周期先提醒一次；严重低电量时每五分钟再次提醒，直到用户确认或接电。
@MainActor
final class AlertCoordinator {
    static let severeLevel = 10
    static let repeatInterval: TimeInterval = 5 * 60
    static let snoozeInterval: TimeInterval = 30 * 60

    private let logger: Logger
    private let now: () -> Date
    private let deliver: (Int, Int, AppSettings) -> Void
    private var armed = true
    private var lastFiredAt: Date?
    private var acknowledged = false
    private(set) var snoozedUntil: Date?
    private let minimumInterval: TimeInterval = 90

    init(
        subsystem: String,
        now: @escaping () -> Date = Date.init,
        deliver: ((Int, Int, AppSettings) -> Void)? = nil
    ) {
        logger = Logger(subsystem: subsystem, category: "AlertCoordinator")
        self.now = now
        self.deliver = deliver ?? { level, threshold, settings in
            Alerter.shared.fire(level: level, threshold: threshold, settings: settings)
        }
    }

    func reset() {
        armed = true
        acknowledged = false
        snoozedUntil = nil
        logger.notice("提醒周期已重置")
    }

    func acknowledge() {
        acknowledged = true
        snoozedUntil = nil
        logger.notice("用户已确认本轮低电量提醒")
    }

    func snooze() {
        let until = now().addingTimeInterval(Self.snoozeInterval)
        snoozedUntil = until
        logger.notice("用户暂停提醒至 \(until.formatted(.iso8601), privacy: .public)")
    }

    func evaluate(level: Int, hasExternalPower: Bool, settings: AppSettings) {
        guard settings.enabled else { return }

        if hasExternalPower || level >= settings.rearmLevel {
            if !armed || acknowledged || snoozedUntil != nil { reset() }
            return
        }

        guard level <= settings.threshold, !acknowledged else { return }
        let timestamp = now()
        if let snoozedUntil, timestamp < snoozedUntil { return }

        let firstAlert = armed
        guard firstAlert || level <= Self.severeLevel else { return }
        let interval = firstAlert ? minimumInterval : Self.repeatInterval
        if let lastFiredAt, timestamp.timeIntervalSince(lastFiredAt) < interval { return }

        armed = false
        snoozedUntil = nil
        lastFiredAt = timestamp
        logger.notice("触发\(firstAlert ? "首次" : "严重低电量重复", privacy: .public)提醒: \(level)% <= \(settings.threshold)%, 时间 \(timestamp.formatted(.iso8601), privacy: .public)")
        deliver(level, settings.threshold, settings)
    }
}
