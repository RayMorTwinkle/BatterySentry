import AppKit
import AVFoundation
import Darwin
import Foundation
import UserNotifications

/// 命令行自检：`BatterySentry.app/Contents/MacOS/BatterySentry --selftest [--speak] [--sound]`
enum SelfTest {
    static func run() {
        print("=== BatterySentry 自检 ===")

        let reading = PowerSourceReader.read()
        print("电池存在: \(reading.hasBattery)")
        print("电量: \(reading.level.map { "\($0)%" } ?? "nil")")
        print("充电中: \(reading.isCharging)")
        print("已接电源: \(reading.isPluggedIn)")

        let defaults = UserDefaults.standard
        let threshold = defaults.object(forKey: "alertThreshold") as? Int ?? 20
        let enabled = defaults.object(forKey: "alertEnabled") as? Bool ?? true
        print("阈值: \(threshold)%  提醒已启用: \(enabled)")

        let voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("zh") }
        print("中文语音数量: \(voices.count)")
        if let voice = AVSpeechSynthesisVoice(language: "zh-CN") {
            print("使用语音: \(voice.name) (\(voice.language))")
        } else {
            print("⚠️ 未找到 zh-CN 语音")
        }

        if CommandLine.arguments.contains("--sound") {
            if let sound = NSSound(named: NSSound.Name("Sosumi")) {
                sound.play()
            } else {
                NSSound.beep()
            }
            RunLoop.current.run(until: Date().addingTimeInterval(1.5))
            print("提示音测试完成")
        }

        if CommandLine.arguments.contains("--speak") {
            let synthesizer = AVSpeechSynthesizer()
            let utterance = AVSpeechUtterance(string: "电量低于百分之\(threshold)，请及时充电。")
            utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
            utterance.rate = 0.48
            synthesizer.speak(utterance)
            RunLoop.current.run(until: Date().addingTimeInterval(6))
            print("语音播报测试完成")
        }

        print("Bundle ID: \(Bundle.main.bundleIdentifier ?? "nil")")

        if Bundle.main.bundleIdentifier != nil {
            let semaphore = DispatchSemaphore(value: 0)
            var statusText = "未知"
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                statusText = "authorization=\(settings.authorizationStatus.rawValue) alert=\(settings.alertSetting.rawValue) sound=\(settings.soundSetting.rawValue)"
                semaphore.signal()
            }
            _ = semaphore.wait(timeout: .now() + 3)
            print("通知授权: \(statusText)")
        }
        print("=== 自检结束 ===")
        exit(0)
    }
}
