import SwiftUI
import AppKit

/// 点击菜单栏图标后弹出的面板
struct MenuContentView: View {
    @EnvironmentObject private var app: AppCoordinator
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var monitor: BatteryMonitor
    @EnvironmentObject private var login: LaunchAtLogin
    @EnvironmentObject private var alerter: Alerter

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.bottom, 12)
            Divider()
            thresholdSection
                .padding(.vertical, 12)
            Divider()
            channelsSection
                .padding(.vertical, 12)
            Divider()
            loginSection
                .padding(.vertical, 12)
            Divider()
            footer
                .padding(.top, 10)
        }
        .padding(16)
        .frame(width: 340)
    }

    // MARK: - 顶部状态

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            BatteryGauge(level: monitor.level, charging: monitor.isCharging, low: isLow)
                .frame(width: 58, height: 26)
                .accessibilityElement()
                .accessibilityLabel(Text("电池电量"))

            VStack(alignment: .leading, spacing: 1) {
                Text(levelText)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                Text("阈值 \(settings.threshold)%")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if isLow {
                    Text("电量偏低")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.red.opacity(0.16)))
                        .foregroundStyle(.red)
                }
            }
        }
    }

    // MARK: - 阈值

    private var thresholdSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("低电量提醒")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Toggle("", isOn: $settings.enabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }

            HStack(spacing: 10) {
                Text("低于")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Slider(value: thresholdBinding, in: 5...60, step: 1)
                    .disabled(!settings.enabled)
                Text("\(settings.threshold)%")
                    .font(.system(.callout, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                    .frame(width: 38, alignment: .trailing)
            }

            Text("电量 ≤ \(settings.threshold)% 时提醒一次；充电或回升到 \(settings.rearmLevel)% 以上后，才会再次提醒。")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .opacity(settings.enabled ? 1 : 0.55)
        .animation(.easeInOut(duration: 0.15), value: settings.enabled)
    }

    // MARK: - 提醒方式

    private var channelsSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("提醒方式")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Toggle("播放提示音", isOn: $settings.playSound)
            Toggle("语音播报（“电量低于 \(settings.threshold)%”）", isOn: $settings.speak)
            Toggle("系统通知", isOn: $settings.notify)

            if settings.notify, alerter.authorizationStatus == .denied {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text("通知权限已被拒绝")
                    Button("打开设置") {
                        alerter.openNotificationSettings()
                    }
                    .buttonStyle(.link)
                    .font(.caption2)
                }
                .font(.caption2)
                .foregroundStyle(.orange)
            }
        }
        .toggleStyle(.checkbox)
    }

    // MARK: - 开机启动

    private var loginSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle("开机时自动启动", isOn: loginBinding)
                .toggleStyle(.switch)
                .controlSize(.small)
                .font(.system(size: 13))

            if let error = login.lastError {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            } else if login.usesFallbackAgent {
                Text("正在使用 LaunchAgent 备用登录项")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - 底部按钮

    private var footer: some View {
        HStack(spacing: 10) {
            Button {
                app.testAlert()
            } label: {
                Label("测试提醒", systemImage: "bell.badge")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

            Button("通知设置") {
                alerter.openNotificationSettings()
            }
            .buttonStyle(.link)
            .font(.caption)

            Spacer()

            Button("退出") {
                app.quit()
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - 辅助

    private var isLow: Bool {
        guard let level = monitor.level else { return false }
        return level <= settings.threshold && !monitor.isCharging
    }

    private var levelText: String {
        monitor.level.map { "\($0)%" } ?? "——"
    }

    private var statusText: String {
        if !monitor.hasBattery { return "未检测到电池（台式机）" }
        if monitor.isCharging { return "正在充电" }
        if monitor.isPluggedIn { return "已接入电源，未充电" }
        return "使用电池供电"
    }

    private var thresholdBinding: Binding<Double> {
        Binding(
            get: { Double(settings.threshold) },
            set: { settings.threshold = Int($0.rounded()) }
        )
    }

    private var loginBinding: Binding<Bool> {
        Binding(
            get: { login.isEnabled },
            set: { login.setEnabled($0) }
        )
    }
}

/// 面板里的电池图形
struct BatteryGauge: View {
    let level: Int?
    let charging: Bool
    let low: Bool

    private var fraction: CGFloat {
        guard let level else { return 0 }
        return CGFloat(min(max(level, 0), 100)) / 100
    }

    private var fillColor: Color {
        if low { return .red }
        if charging { return .green }
        return .accentColor
    }

    var body: some View {
        HStack(spacing: 2) {
            GeometryReader { proxy in
                let width = proxy.size.width
                let height = proxy.size.height

                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.primary.opacity(0.08))
                        .padding(3)

                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(fillColor.gradient)
                        .frame(width: max(3, (width - 6) * fraction), height: max(3, height - 6))
                        .offset(x: 3, y: 3)
                }
                .frame(width: width, height: height)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.45), lineWidth: 1.5)
                )
                .overlay {
                    if charging {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.25), radius: 0.5)
                    }
                }
            }

            Capsule()
                .fill(Color.primary.opacity(0.45))
                .frame(width: 3.5, height: 9)
        }
    }
}
