import SwiftUI

@main
struct AgentPhoneApp: App {
    var body: some Scene {
        WindowGroup {
            CompanionHomeView()
                .preferredColorScheme(.dark)
        }
    }
}
