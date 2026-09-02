import Testing
@testable import JarvisCore

@Suite("JARVIS core")
struct JarvisCoreTests {
    @Test("Korean app launch command is interpreted")
    func appLaunchInterpretation() {
        let action = CommandInterpreter().interpret("Xcode 열어줘")
        #expect(action == .openApplication("xcode"))
    }

    @Test("App launch requires confirmation")
    func appLaunchRequiresApproval() {
        let requirement = ActionPolicy().approvalRequirement(for: .openApplication("xcode"))
        #expect(requirement == .userConfirmation(reason: "xcode 앱을 실행합니다."))
    }

    @Test("Read-only commands run automatically")
    func statusRunsAutomatically() {
        let requirement = ActionPolicy().approvalRequirement(for: .showStatus)
        #expect(requirement == .automatic)
    }
}
