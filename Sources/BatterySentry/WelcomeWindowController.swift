import AppKit
import SwiftUI

/// 首次启动且菜单栏图标被管理工具隐藏时，弹一个设置窗口，保证用户能找到它。
struct WelcomeView: View {
    let coordinator: AppCoordinator

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                Text("菜单栏图标被 Ice 等菜单栏管理工具收进了隐藏区。在 Ice 里把它拖到可见区即可；低电量提醒已经在后台工作。")
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .font(.caption)
            .foregroundStyle(.orange)
            .padding(10)
            .frame(width: 340, alignment: .leading)
            .background(Color.orange.opacity(0.1))

            MenuContentView()
                .environmentObject(coordinator)
                .environmentObject(coordinator.settings)
                .environmentObject(coordinator.monitor)
                .environmentObject(coordinator.launchAtLogin)
                .environmentObject(coordinator.alerter)
        }
    }
}

@MainActor
final class WelcomeWindowController: NSWindowController {
    init(coordinator: AppCoordinator) {
        let hosting = NSHostingController(rootView: WelcomeView(coordinator: coordinator))
        let window = NSWindow(contentViewController: hosting)
        window.title = "电量哨兵"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)

        hosting.view.layoutSubtreeIfNeeded()
        let size = hosting.view.fittingSize
        if size.height > 100 {
            window.setContentSize(NSSize(width: 340, height: size.height))
        }
        window.center()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    var isVisible: Bool {
        window?.isVisible ?? false
    }
}
