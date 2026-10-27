import AppKit
import Combine
import SwiftUI

/// 菜单栏常驻图标（NSStatusItem）+ 点击弹出的面板（NSPopover）
@MainActor
final class StatusItemController: NSObject {
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private let coordinator: AppCoordinator
    private var cancellables = Set<AnyCancellable>()

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleNone
            button.setAccessibilityLabel("电量哨兵")
        }

        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 340, height: 420)
        popover.contentViewController = NSHostingController(rootView: panelContent)

        observeState()
        updateButton()
    }

    /// 菜单栏图标是否被 Ice / Bartender 之类的管理工具挪到屏幕外
    var isHiddenByManager: Bool {
        guard let frame = statusItem.button?.window?.frame else { return false }
        return frame.minX < 0
    }

    // MARK: - 面板

    private var panelContent: some View {
        MenuContentView()
            .environmentObject(coordinator)
            .environmentObject(coordinator.settings)
            .environmentObject(coordinator.monitor)
            .environmentObject(coordinator.launchAtLogin)
            .environmentObject(coordinator.alerter)
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            presentPopover()
        }
    }

    private func presentPopover() {
        guard let button = statusItem.button else { return }

        // 让 SwiftUI 先量出内容高度，避免面板底部留白
        if let view = popover.contentViewController?.view {
            view.layoutSubtreeIfNeeded()
            let fitting = view.fittingSize
            if fitting.height > 100 {
                popover.contentSize = NSSize(width: max(340, fitting.width), height: fitting.height)
            }
        }

        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// 开发用：把状态栏按钮离屏渲染成 PNG，检查图标/文字的布局
    func dumpButtonImage(to path: String) {
        guard let button = statusItem.button else {
            print("没有 button")
            return
        }
        print("button.bounds = \(button.bounds)")
        print("button.font = \(String(describing: button.font))")
        print("image.size = \(String(describing: button.image?.size)) reps = \(String(describing: button.image?.representations.map { "\($0.pixelsWide)x\($0.pixelsHigh) size=\($0.size)" }))")
        print("imageScaling = \(button.imageScaling.rawValue) title = \(button.title)")

        guard button.bounds.width > 0,
              let rep = button.bitmapImageRepForCachingDisplay(in: button.bounds) else { return }
        button.cacheDisplay(in: button.bounds, to: rep)
        if let data = rep.representation(using: .png, properties: [:]) {
            try? data.write(to: URL(fileURLWithPath: path))
            print("已输出 \(path)")
        }
    }

    // MARK: - 状态

    private func observeState() {
        let monitor = coordinator.monitor
        let settings = coordinator.settings

        monitor.$level.sink { [weak self] _ in self?.updateButton() }.store(in: &cancellables)
        monitor.$isCharging.sink { [weak self] _ in self?.updateButton() }.store(in: &cancellables)
        monitor.$hasBattery.sink { [weak self] _ in self?.updateButton() }.store(in: &cancellables)
        settings.$threshold.sink { [weak self] _ in self?.updateButton() }.store(in: &cancellables)
    }

    private func updateButton() {
        guard let button = statusItem.button else { return }
        let monitor = coordinator.monitor
        let settings = coordinator.settings
        let level = monitor.level
        let charging = monitor.isCharging
        let isLow = level.map { $0 <= settings.threshold && !charging } ?? false

        if monitor.hasBattery {
            button.image = BatteryIcon.image(level: level, charging: charging, low: isLow)
            button.image?.accessibilityDescription = tooltip(level: level, charging: charging, isLow: isLow)
        } else if let plug = NSImage(systemSymbolName: "powerplug", accessibilityDescription: "外接电源") {
            plug.isTemplate = true
            button.image = plug
        }

        button.title = ""

        button.toolTip = tooltip(level: level, charging: charging, isLow: isLow)
        button.setAccessibilityLabel(tooltip(level: level, charging: charging, isLow: isLow))
    }

    private func tooltip(level: Int?, charging: Bool, isLow: Bool) -> String {
        guard let level else { return "电量哨兵 · 未检测到电池" }
        var text = "电量哨兵 · 电池 \(level)%"
        if charging { text += "（充电中）" }
        if isLow { text += " · 低于阈值 \(coordinator.settings.threshold)%" }
        return text
    }
}
