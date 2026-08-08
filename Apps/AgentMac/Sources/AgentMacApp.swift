import AgentUI
import AppKit
import SwiftUI

@main
struct AgentMacApp: App {
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
