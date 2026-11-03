import AppKit
import Combine
import Foundation
import os.log

/// 应用级组装：持有设置、监听、提醒器，并把它们串起来。
@MainActor
final class AppCoordinator: ObservableObject {
    let settings: AppSettings
    let monitor: BatteryMonitor
    let launchAtLogin: LaunchAtLogin
    let alerter: Alerter
    let logger: Logger
    @Published private(set) var reminderStatus = ""
    @Published private(set) var delayedTestStatus = ""

    private let alerts: AlertCoordinator
    private var delayedTestTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    init() {
        let bundleID = Bundle.main.bundleIdentifier ?? "BatterySentry"
        logger = Logger(subsystem: bundleID, category: "App")

        settings = AppSettings()
        monitor = BatteryMonitor()
        launchAtLogin = LaunchAtLogin()
        alerter = Alerter.shared
        alerts = AlertCoordinator(subsystem: bundleID)
        alerter.onAcknowledge = { [weak self] in self?.acknowledgeReminder() }
        alerter.onSnooze = { [weak self] in self?.snoozeReminder() }

        // 阈值/开关变化后立即重新判断
        settings.$threshold
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] _ in
                guard let self else { return }
                self.alerts.reset()
                self.evaluateNow()
            }
            .store(in: &cancellables)

        settings.$enabled
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] enabled in
                guard let self, enabled else { return }
                self.alerts.reset()
                self.evaluateNow()
            }
            .store(in: &cancellables)

        monitor.start()

        // 启动 1 秒后请求通知权限（不要挡住菜单栏图标的出现）
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.alerter.requestNotificationAuthorizationIfNeeded()
        }

        // 启动 3 秒后开始评估，避免"一登录就低于阈值"时通知权限还没就绪
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            guard let self else { return }
            self.monitor.onChange = { [weak self] level, charging in
                guard let self else { return }
                self.alerts.evaluate(level: level, hasExternalPower: charging || self.monitor.isPluggedIn,
                                     settings: self.settings)
            }
            self.evaluateNow()
        }
    }

    func evaluateNow() {
        guard let level = monitor.level else { return }
        alerts.evaluate(level: level, hasExternalPower: monitor.isCharging || monitor.isPluggedIn,
                        settings: settings)
    }

    func testAlert() {
        alerter.fireTest(settings: settings)
    }

    func scheduleDelayedTest() {
        delayedTestTimer?.invalidate()
        let scheduledAt = Date()
        let dueAt = scheduledAt.addingTimeInterval(30)
        let foreground = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "未知"
        delayedTestStatus = "已安排：\(dueAt.formatted(date: .omitted, time: .standard))"
        logger.notice("延迟测试已安排: \(scheduledAt.formatted(.iso8601), privacy: .public), 预计 \(dueAt.formatted(.iso8601), privacy: .public), 前台 \(foreground, privacy: .public)")

        let timer = Timer(timeInterval: 30, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let actual = Date()
                let foreground = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "未知"
                self.delayedTestStatus = "已触发：\(actual.formatted(date: .omitted, time: .standard))（延迟 \(Int(actual.timeIntervalSince(dueAt))) 秒）"
                self.logger.notice("延迟测试已触发: \(actual.formatted(.iso8601), privacy: .public), 相对预定延迟 \(actual.timeIntervalSince(dueAt)) 秒, 前台 \(foreground, privacy: .public)")
                self.alerter.fireTest(settings: self.settings)
                self.delayedTestTimer = nil
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        delayedTestTimer = timer
    }

    func acknowledgeReminder() {
        alerts.acknowledge()
        reminderStatus = "本轮低电量提醒已确认"
    }

    func snoozeReminder() {
        alerts.snooze()
        reminderStatus = "已暂停至 \(alerts.snoozedUntil?.formatted(date: .omitted, time: .standard) ?? "")"
    }

    func quit() {
        logger.notice("用户退出应用")
        NSApp.terminate(nil)
    }
}
