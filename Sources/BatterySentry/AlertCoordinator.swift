import Foundation
import os.log

/// 判断"该不该响"：一次低电量只提醒一次，充电或电量回升后重新武装。
@MainActor
final class AlertCoordinator {
    private let logger: Logger
    private var armed = true
    private var lastFiredAt: Date?
    /// 两次提醒之间的最小间隔，避免阈值反复抖动
    private let minimumInterval: TimeInterval = 90

    init(subsystem: String) {
        logger = Logger(subsystem: subsystem, category: "AlertCoordinator")
    }

    func reset() {
        armed = true
        logger.debug("提醒已重新武装")
    }

    func evaluate(level: Int, isCharging: Bool, settings: AppSettings) {
        guard settings.enabled else { return }

        let threshold = settings.threshold
        let rearmLevel = settings.rearmLevel

        // 充电中，或电量已经回到阈值以上 -> 重新武装
        if isCharging || level >= rearmLevel {
            armed = true
            return
        }

        guard armed, level <= threshold else { return }

        if let lastFiredAt, Date().timeIntervalSince(lastFiredAt) < minimumInterval {
            logger.debug("距上次提醒不足 \(Int(self.minimumInterval)) 秒，跳过")
            return
        }

        armed = false
        lastFiredAt = Date()
        logger.notice("触发低电量提醒：\(level)% <= 阈值 \(threshold)%")
        Alerter.shared.fire(level: level, threshold: threshold, settings: settings)
    }
}
