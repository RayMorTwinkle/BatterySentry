import Foundation
import ServiceManagement
import os.log

/// 开机启动：优先用 macOS 13+ 的 SMAppService，失败时退回 LaunchAgent。
@MainActor
final class LaunchAtLogin: ObservableObject {
    @Published private(set) var isEnabled = false
    @Published private(set) var usesFallbackAgent = false
    @Published private(set) var lastError: String?

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "BatterySentry",
        category: "LaunchAtLogin"
    )
    private let agentLabel = "com.ray.batterysentry.loginagent"
    private let fileManager = FileManager.default

    init() {
        refresh()
    }

    var agentURL: URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
            .appendingPathComponent("\(agentLabel).plist")
    }

    func refresh() {
        let agentInstalled = fileManager.fileExists(atPath: agentURL.path)
        usesFallbackAgent = agentInstalled

        var serviceEnabled = false
        if #available(macOS 13.0, *) {
            serviceEnabled = SMAppService.mainApp.status == .enabled
        }
        isEnabled = serviceEnabled || agentInstalled
    }

    func setEnabled(_ enabled: Bool) {
        lastError = nil
        if enabled {
            enable()
        } else {
            disable()
        }
        refresh()
    }

    private func enable() {
        if #available(macOS 13.0, *) {
            do {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
                removeFallbackAgent()
                logger.notice("登录项已注册（SMAppService）")
                return
            } catch {
                logger.error("SMAppService 注册失败: \(error.localizedDescription, privacy: .public)")
            }
        }

        do {
            try installFallbackAgent()
            lastError = "系统登录项注册失败，已改用 LaunchAgent 备用方案（下次登录生效）。"
            logger.notice("已安装 LaunchAgent 备用登录项")
        } catch {
            lastError = "开机启动设置失败：\(error.localizedDescription)"
            logger.error("LaunchAgent 安装失败: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func disable() {
        if #available(macOS 13.0, *) {
            do {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                lastError = "取消系统登录项失败：\(error.localizedDescription)"
                logger.error("SMAppService 注销失败: \(error.localizedDescription, privacy: .public)")
            }
        }
        removeFallbackAgent()
    }

    // MARK: - LaunchAgent 备用方案

    private func installFallbackAgent() throws {
        let appURL = Bundle.main.bundleURL
        guard appURL.pathExtension == "app" else {
            throw NSError(
                domain: "BatterySentry",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "当前不是以 .app 方式运行，请先构建并运行 dist/BatterySentry.app"]
            )
        }

        try fileManager.createDirectory(
            at: agentURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let plist: [String: Any] = [
            "Label": agentLabel,
            "ProgramArguments": ["/usr/bin/open", "-a", appURL.path],
            "RunAtLoad": true,
            "ProcessType": "Interactive",
            "LimitLoadToSessionType": "Aqua",
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: agentURL, options: .atomic)

        // 立即尝试加载；即使失败，下次登录也会由 launchd 加载
        _ = runLaunchctl(["bootstrap", "gui/\(getuid())", agentURL.path])
    }

    private func removeFallbackAgent() {
        guard fileManager.fileExists(atPath: agentURL.path) else { return }
        _ = runLaunchctl(["bootout", "gui/\(getuid())/\(agentLabel)"])
        try? fileManager.removeItem(at: agentURL)
    }

    @discardableResult
    private func runLaunchctl(_ arguments: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus
        } catch {
            logger.error("launchctl 执行失败: \(error.localizedDescription, privacy: .public)")
            return -1
        }
    }
}
