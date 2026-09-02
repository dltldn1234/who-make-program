import AgentUI
import SwiftUI

@main
struct JarvisHUDApp: App {
    var body: some Scene {
        WindowGroup {
            HUDRootView()
                .frame(minWidth: 960, minHeight: 640)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1200, height: 760)
    }
}
