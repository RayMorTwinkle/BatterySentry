import AppKit
import SwiftUI

/// 开发用：把设置面板离屏渲染成 PNG，便于检查视觉效果。
/// 用法：BatterySentry --snapshot
enum Snapshot {
    @MainActor
    static func run(coordinator: AppCoordinator) {
        renderPanel(coordinator: coordinator)
        print("已输出 /tmp/batterysentry-panel.png")
    }

    @MainActor
    private static func renderPanel(coordinator: AppCoordinator) {
        let content = MenuContentView()
            .environmentObject(coordinator)
            .environmentObject(coordinator.settings)
            .environmentObject(coordinator.monitor)
            .environmentObject(coordinator.launchAtLogin)
            .environmentObject(coordinator.alerter)
            .frame(width: 340)
            .background(Color(nsColor: .windowBackgroundColor))

        let hosting = NSHostingView(rootView: content)
        hosting.frame = NSRect(x: 0, y: 0, width: 340, height: 600)
        hosting.layoutSubtreeIfNeeded()
        let fitting = hosting.fittingSize
        let height = fitting.height > 100 ? fitting.height : 600
        hosting.frame = NSRect(x: 0, y: 0, width: 340, height: height)
        hosting.layoutSubtreeIfNeeded()

        guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else { return }
        hosting.cacheDisplay(in: hosting.bounds, to: rep)
        if let data = rep.representation(using: .png, properties: [:]) {
            try? data.write(to: URL(fileURLWithPath: "/tmp/batterysentry-panel.png"))
            print("面板尺寸: \(hosting.bounds.size)")
        }
    }
}
