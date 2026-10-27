import Foundation
import IOKit.ps
import Combine
import os.log

/// 一次电池采样结果
struct BatteryReading {
    var level: Int?
    var isCharging: Bool
    var isPluggedIn: Bool
    var hasBattery: Bool
    var timestamp: Date
}

/// 只读的 IOKit 电源信息来源读取器
enum PowerSourceReader {
    static func read() -> BatteryReading {
        var reading = BatteryReading(
            level: nil,
            isCharging: false,
            isPluggedIn: false,
            hasBattery: false,
            timestamp: Date()
        )

        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] else {
            return reading
        }

        for source in sources {
            guard let info = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }
            guard (info[kIOPSTypeKey] as? String) == (kIOPSInternalBatteryType as String) else { continue }

            let present = info[kIOPSIsPresentKey] as? Bool ?? true
            guard present else { continue }

            reading.hasBattery = true

            if let current = info[kIOPSCurrentCapacityKey] as? Int,
               let maxCapacity = info[kIOPSMaxCapacityKey] as? Int,
               maxCapacity > 0 {
                reading.level = Int((Double(current) / Double(maxCapacity) * 100).rounded())
            }

            reading.isCharging = info[kIOPSIsChargingKey] as? Bool ?? false
            reading.isPluggedIn = (info[kIOPSPowerSourceStateKey] as? String) == (kIOPSACPowerValue as String)
        }

        return reading
    }
}

/// 监听电池状态：IOKit 电源事件 + 兜底轮询
@MainActor
final class BatteryMonitor: ObservableObject {
    @Published private(set) var level: Int?
    @Published private(set) var isCharging = false
    @Published private(set) var isPluggedIn = false
    @Published private(set) var hasBattery = false
    @Published private(set) var lastUpdated = Date()

    /// 每次采样后回调（主线程）
    var onChange: ((Int, Bool) -> Void)?

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "BatterySentry",
        category: "Battery"
    )
    private var runLoopSource: CFRunLoopSource?
    private var pollTimer: Timer?
    private var started = false

    func start() {
        guard !started else { return }
        started = true
        refresh()

        // IOKit 电源变化通知
        let context = Unmanaged.passUnretained(self).toOpaque()
        if let source = IOPSNotificationCreateRunLoopSource({ rawContext in
            guard let rawContext else { return }
            let monitor = Unmanaged<BatteryMonitor>.fromOpaque(rawContext).takeUnretainedValue()
            DispatchQueue.main.async {
                monitor.refresh()
            }
        }, context)?.takeRetainedValue() {
            runLoopSource = source
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
            logger.debug("已注册 IOKit 电源变化通知")
        } else {
            logger.error("IOKit 电源变化通知注册失败，将依赖轮询")
        }

        // 兜底：每 60 秒采样一次
        let timer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
        timer.tolerance = 10
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    func refresh() {
        let reading = PowerSourceReader.read()
        level = reading.level
        isCharging = reading.isCharging
        isPluggedIn = reading.isPluggedIn
        hasBattery = reading.hasBattery
        lastUpdated = reading.timestamp

        if let level = reading.level {
            onChange?(level, reading.isCharging)
        }
    }
}
