import Foundation
import Combine

/// 用户偏好，全部持久化在 UserDefaults 中。
@MainActor
final class AppSettings: ObservableObject {
    /// 阈值允许范围（%）
    static let thresholdRange = 5...60
    static let severeRange = 5...30
    static let repeatMinutesRange = 1...30
    /// 电量回升多少个百分点后重新武装提醒
    static let rearmMargin = 3

    enum Key {
        static let enabled = "alertEnabled"
        static let threshold = "alertThreshold"
        static let severeLevel = "severeLevel"
        static let repeatMinutes = "repeatMinutes"
        static let playSound = "playSound"
        static let speak = "speakWarning"
        static let notify = "systemNotification"
        static let fullscreenAlert = "fullscreenAlert"
    }

    private let defaults: UserDefaults

    @Published var enabled: Bool { didSet { defaults.set(enabled, forKey: Key.enabled) } }
    @Published var threshold: Int {
        didSet {
            defaults.set(threshold, forKey: Key.threshold)
            if severeLevel > threshold { severeLevel = threshold }
        }
    }
    @Published var severeLevel: Int { didSet { defaults.set(severeLevel, forKey: Key.severeLevel) } }
    @Published var repeatMinutes: Int { didSet { defaults.set(repeatMinutes, forKey: Key.repeatMinutes) } }
    @Published var playSound: Bool { didSet { defaults.set(playSound, forKey: Key.playSound) } }
    @Published var speak: Bool { didSet { defaults.set(speak, forKey: Key.speak) } }
    @Published var notify: Bool { didSet { defaults.set(notify, forKey: Key.notify) } }
    @Published var fullscreenAlert: Bool { didSet { defaults.set(fullscreenAlert, forKey: Key.fullscreenAlert) } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.enabled: true,
            Key.threshold: 20,
            Key.severeLevel: 10,
            Key.repeatMinutes: 5,
            Key.playSound: true,
            Key.speak: true,
            Key.notify: true,
            Key.fullscreenAlert: true,
        ])

        enabled = defaults.bool(forKey: Key.enabled)
        let initialThreshold = min(
            max(defaults.integer(forKey: Key.threshold), Self.thresholdRange.lowerBound),
            Self.thresholdRange.upperBound
        )
        threshold = initialThreshold
        severeLevel = min(max(defaults.integer(forKey: Key.severeLevel), Self.severeRange.lowerBound),
                          min(Self.severeRange.upperBound, initialThreshold))
        repeatMinutes = min(max(defaults.integer(forKey: Key.repeatMinutes), Self.repeatMinutesRange.lowerBound),
                            Self.repeatMinutesRange.upperBound)
        playSound = defaults.bool(forKey: Key.playSound)
        speak = defaults.bool(forKey: Key.speak)
        notify = defaults.bool(forKey: Key.notify)
        fullscreenAlert = defaults.bool(forKey: Key.fullscreenAlert)
    }

    /// 重新提醒的阈值（例如阈值 20% -> 23%）
    var rearmLevel: Int {
        min(100, threshold + Self.rearmMargin)
    }
}
