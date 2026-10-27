import AppKit
import AVFoundation
import UserNotifications
import os.log

/// 负责真正"发出"提醒：提示音 + 语音播报 + 系统通知
@MainActor
final class Alerter: ObservableObject {
    static let shared = Alerter()

    /// 系统通知授权状态，供设置界面展示
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private let logger: Logger
    private let synthesizer = AVSpeechSynthesizer()
    private let notificationPresenter = NotificationPresenter()
    private var activeSounds: [NSSound] = []
    private var authorizationRequested = false

    private init() {
        logger = Logger(
            subsystem: Bundle.main.bundleIdentifier ?? "BatterySentry",
            category: "Alerter"
        )
    }

    // MARK: - 通知授权

    func requestNotificationAuthorizationIfNeeded() {
        guard Bundle.main.bundleIdentifier != nil else {
            logger.error("当前进程没有 bundle id，系统通知不可用（请通过 .app 启动）")
            return
        }

        let center = UNUserNotificationCenter.current()
        center.delegate = notificationPresenter
        center.getNotificationSettings { [weak self] settings in
            Task { @MainActor in
                guard let self else { return }
                self.authorizationStatus = settings.authorizationStatus

                guard settings.authorizationStatus == .notDetermined,
                      !self.authorizationRequested else { return }
                self.authorizationRequested = true

                center.requestAuthorization(options: [.alert, .sound]) { granted, error in
                    if let error {
                        self.logger.error("通知授权失败: \(error.localizedDescription, privacy: .public)")
                    }
                    Task { @MainActor in
                        self.authorizationStatus = granted ? .authorized : .denied
                        self.logger.notice("系统通知授权: \(granted ? "已允许" : "已拒绝", privacy: .public)")
                    }
                }
            }
        }
    }

    func openNotificationSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: - 提醒

    func fire(level: Int, threshold: Int, settings: AppSettings) {
        logger.notice("发出提醒: 当前 \(level)%，阈值 \(threshold)%")

        if settings.playSound {
            playAlertSound()
        }

        if settings.speak {
            let delay = settings.playSound ? 1.0 : 0
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.speakWarning(level: level, threshold: threshold)
            }
        }

        if settings.notify {
            postNotification(level: level, threshold: threshold, silent: settings.playSound)
        }
    }

    /// 面板上的"测试提醒"：用模拟电量触发一遍完整流程
    func fireTest(settings: AppSettings) {
        let simulatedLevel = max(1, settings.threshold - 5)
        fire(level: simulatedLevel, threshold: settings.threshold, settings: settings)
    }

    // MARK: - 提示音

    private func playAlertSound() {
        playNamedSound("Sosumi", volume: 0.9)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            self?.playNamedSound("Sosumi", volume: 0.7)
        }
    }

    private func playNamedSound(_ name: String, volume: Float) {
        activeSounds.removeAll { !$0.isPlaying }
        guard let sound = NSSound(named: NSSound.Name(name)) else {
            NSSound.beep()
            return
        }
        sound.volume = volume
        sound.play()
        activeSounds.append(sound)
    }

    // MARK: - 语音播报

    private func speakWarning(level: Int, threshold: Int) {
        let text = "警告，电量已低于百分之\(threshold)。当前电量百分之\(level)，请尽快连接电源充电。"
        let utterance = AVSpeechUtterance(string: text)
        if let voice = AVSpeechSynthesisVoice(language: "zh-CN") {
            utterance.voice = voice
        } else {
            logger.error("未找到 zh-CN 语音，使用系统默认语音")
        }
        utterance.rate = 0.48
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0

        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        synthesizer.speak(utterance)
        logger.notice("语音播报: \(text, privacy: .public)")
    }

    // MARK: - 系统通知

    private func postNotification(level: Int, threshold: Int, silent: Bool) {
        guard Bundle.main.bundleIdentifier != nil else {
            logger.error("没有 bundle id，跳过系统通知")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "电量低于 \(threshold)%"
        content.body = "当前电量 \(level)%，请尽快连接电源充电。"
        content.sound = silent ? nil : .default
        content.interruptionLevel = .active

        let identifier = "low-battery-\(Int(Date().timeIntervalSince1970))"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)

        UNUserNotificationCenter.current().add(request) { [logger] error in
            if let error {
                logger.error("通知发送失败: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}

/// 让通知在应用处于前台时也能以横幅展示
final class NotificationPresenter: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }
}
