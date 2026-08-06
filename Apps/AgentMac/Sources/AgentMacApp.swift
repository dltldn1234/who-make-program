import AgentUI
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
    }
}
