import AppKit
import Darwin
import SwiftUI

@main
struct BatterySentryApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // 纯菜单栏应用：不需要主窗口，Settings 场景只是占位
        Settings {
            EmptyView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var coordinator: AppCoordinator?
    private var statusItemController: StatusItemController?
    private var welcomeWindowController: WelcomeWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        if CommandLine.arguments.contains("--selftest") {
            SelfTest.run()
        }

        terminateDuplicateInstanceIfNeeded()

        let coordinator = AppCoordinator()
        self.coordinator = coordinator

        if CommandLine.arguments.contains("--snapshot") {
            Snapshot.run(coordinator: coordinator)
            exit(0)
        }

        self.statusItemController = StatusItemController(coordinator: coordinator)

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            let forced = CommandLine.arguments.contains("--welcome")
            let shownBefore = UserDefaults.standard.bool(forKey: "hasShownWelcomeWindow")
            guard forced || (self.statusItemController?.isHiddenByManager == true && !shownBefore) else { return }
            UserDefaults.standard.set(true, forKey: "hasShownWelcomeWindow")
            let controller = WelcomeWindowController(coordinator: coordinator)
            self.welcomeWindowController = controller
            controller.show()
        }

        if CommandLine.arguments.contains("--dump-status") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.statusItemController?.dumpButtonImage(to: "/tmp/batterysentry-status.png")
            }
        }

        if CommandLine.arguments.contains("--test-alert") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                coordinator.alerter.fire(
                    level: max(1, coordinator.settings.threshold - 5),
                    threshold: coordinator.settings.threshold,
                    settings: coordinator.settings
                )
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func terminateDuplicateInstanceIfNeeded() {
        guard let bundleID = Bundle.main.bundleIdentifier else { return }
        let currentPID = ProcessInfo.processInfo.processIdentifier
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter { $0.processIdentifier != currentPID }

        if let other = others.first {
            other.activate(options: [])
            NSApp.terminate(nil)
        }
    }
}
