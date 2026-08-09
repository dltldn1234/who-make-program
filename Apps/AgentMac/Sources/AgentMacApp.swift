import AgentUI
import AppKit
import SwiftUI

@main
struct AgentMacApp: App {
    @NSApplicationDelegateAdaptor(AgentMacDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup(id: "main") {
            HUDRootView()
                .frame(minWidth: 960, minHeight: 640)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1200, height: 760)
        .defaultLaunchBehavior(.presented)

        MenuBarExtra("Agent", systemImage: "circle.hexagongrid.fill") {
            AgentMenuBarView()
        }
        .menuBarExtraStyle(.menu)
    }
}

@MainActor
private final class AgentMacDelegate: NSObject, NSApplicationDelegate {
    private var fallbackWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
        restoreMainWindow(remainingAttempts: 20)
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        if !NSApplication.shared.windows.contains(where: { $0.isVisible && $0.canBecomeMain }) {
            restoreMainWindow(remainingAttempts: 20)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            restoreMainWindow(remainingAttempts: 20)
        }
        return true
    }

    private func restoreMainWindow(remainingAttempts: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let window = NSApplication.shared.windows.first(where: { $0.canBecomeMain }) else {
                if remainingAttempts > 1 {
                    self?.restoreMainWindow(remainingAttempts: remainingAttempts - 1)
                } else {
                    self?.presentFallbackWindow()
                }
                return
            }
            window.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }

    private func presentFallbackWindow() {
        if let fallbackWindow {
            fallbackWindow.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            return
        }

        let controller = NSHostingController(
            rootView: HUDRootView().frame(minWidth: 960, minHeight: 640)
        )
        let window = NSWindow(contentViewController: controller)
        window.setContentSize(NSSize(width: 1200, height: 760))
        window.minSize = NSSize(width: 960, height: 640)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.fullSizeContentView)
        window.center()
        window.isReleasedWhenClosed = false
        fallbackWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}

private struct AgentMenuBarView: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("에이전트 열기") {
            openWindow(id: "main")
            NSApplication.shared.activate()
        }

        Divider()

        Button("종료") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
