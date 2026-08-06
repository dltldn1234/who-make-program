import Foundation

public struct ActionPolicy: Sendable {
    public init() {}

    public func approvalRequirement(for action: JarvisAction) -> ApprovalRequirement {
        switch action {
        case .showHelp, .showStatus, .tellTime, .unknown:
            return .automatic
        case let .openApplication(name):
            return .userConfirmation(reason: "\(name) 앱을 실행합니다.")
        }
    }
}
