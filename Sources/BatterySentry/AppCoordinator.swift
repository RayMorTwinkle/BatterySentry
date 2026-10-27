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

    private let alerts: AlertCoordinator
    private var cancellables = Set<AnyCancellable>()

    init() {
        let bundleID = Bundle.main.bundleIdentifier ?? "BatterySentry"
        logger = Logger(subsystem: bundleID, category: "App")

        settings = AppSettings()
        monitor = BatteryMonitor()
        launchAtLogin = LaunchAtLogin()
        alerter = Alerter.shared
        alerts = AlertCoordinator(subsystem: bundleID)

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
                self.alerts.evaluate(level: level, isCharging: charging, settings: self.settings)
            }
            self.evaluateNow()
        }
    }

    func evaluateNow() {
        guard let level = monitor.level else { return }
        alerts.evaluate(level: level, isCharging: monitor.isCharging, settings: settings)
    }

    func testAlert() {
        alerter.fireTest(settings: settings)
    }

    func quit() {
        logger.notice("用户退出应用")
        NSApp.terminate(nil)
    }
}
