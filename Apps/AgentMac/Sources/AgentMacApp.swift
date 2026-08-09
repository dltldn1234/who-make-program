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

        MenuBarExtra("Agent", systemImage: "circle.hexagongrid.fill") {
            AgentMenuBarView()
        }
        .menuBarExtraStyle(.menu)
    }
}

private final class AgentMacDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
        restoreMainWindow()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            restoreMainWindow()
        }
        return true
    }

    private func restoreMainWindow() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            guard let window = NSApplication.shared.windows.first(where: { $0.canBecomeMain }) else {
                return
            }
            window.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
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
