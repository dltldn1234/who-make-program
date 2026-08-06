import Foundation

public enum JarvisAction: Equatable, Sendable {
    case showHelp
    case showStatus
    case tellTime
    case openApplication(String)
    case unknown(String)
}

public enum ApprovalRequirement: Equatable, Sendable {
    case automatic
    case userConfirmation(reason: String)
}

public struct JarvisResponse: Equatable, Sendable {
    public let message: String
    public let succeeded: Bool

    public init(message: String, succeeded: Bool) {
        self.message = message
        self.succeeded = succeeded
    }
}
