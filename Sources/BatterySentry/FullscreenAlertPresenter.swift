import AppKit
import SwiftUI

/// 在当前 Space（包括全屏 App 的 Space）显示短暂的应用内提醒。
/// 使用不激活的面板，避免把游戏切到后台。
@MainActor
final class FullscreenAlertPresenter {
    private var panels: [NSPanel] = []
    private var dismissTask: DispatchWorkItem?

    func show(level: Int, threshold: Int) {
        dismiss()

        // 每个显示器各显示一份，游戏运行在哪块屏幕上都能看见。
        for screen in NSScreen.screens {
            let size = NSSize(width: 420, height: 112)
            let frame = NSRect(
                x: screen.frame.midX - size.width / 2,
                y: screen.frame.maxY - size.height - 48,
                width: size.width,
                height: size.height
            )
            let panel = NSPanel(
                contentRect: frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.level = .screenSaver
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            panel.hidesOnDeactivate = false
            panel.isReleasedWhenClosed = false
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = true
            panel.contentView = NSHostingView(rootView: FullscreenAlertView(
                level: level,
                threshold: threshold,
                dismiss: { [weak self] in self?.dismiss() }
            ))
            panel.orderFrontRegardless()
            panels.append(panel)
        }

        let task = DispatchWorkItem { [weak self] in self?.dismiss() }
        dismissTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 25, execute: task)
    }

    private func dismiss() {
        dismissTask?.cancel()
        dismissTask = nil
        panels.forEach { $0.close() }
        panels.removeAll()
    }
}

private struct FullscreenAlertView: View {
    let level: Int
    let threshold: Int
    let dismiss: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "battery.25percent")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(.red)

            VStack(alignment: .leading, spacing: 5) {
                Text("电量低于 \(threshold)%")
                    .font(.system(size: 18, weight: .bold))
                Text("当前电量 \(level)%，请尽快连接电源。")
                    .font(.system(size: 14))
            }

            Spacer(minLength: 0)

            Button(action: dismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 19))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("关闭低电量提醒")
        }
        .padding(.horizontal, 18)
        .frame(width: 420, height: 112)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.red.opacity(0.45), lineWidth: 2))
        .padding(2)
    }
}
