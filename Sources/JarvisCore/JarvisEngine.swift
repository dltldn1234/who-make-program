import Foundation

public protocol JarvisActionExecuting: Sendable {
    func execute(_ action: JarvisAction) async -> JarvisResponse
}

public actor JarvisEngine {
    private let interpreter: CommandInterpreter
    private let policy: ActionPolicy
    private let executor: any JarvisActionExecuting

    public init(
        interpreter: CommandInterpreter = CommandInterpreter(),
        policy: ActionPolicy = ActionPolicy(),
        executor: any JarvisActionExecuting
    ) {
        self.interpreter = interpreter
        self.policy = policy
        self.executor = executor
    }

    public func prepare(_ command: String) -> PreparedCommand {
        let action = interpreter.interpret(command)
        return PreparedCommand(
            originalCommand: command,
            action: action,
            approval: policy.approvalRequirement(for: action)
        )
    }

    public func execute(_ prepared: PreparedCommand, approved: Bool) async -> JarvisResponse {
        if case .userConfirmation = prepared.approval, !approved {
            return JarvisResponse(message: "명령을 취소했습니다.", succeeded: false)
        }
        return await executor.execute(prepared.action)
    }
}

public struct PreparedCommand: Equatable, Sendable {
    public let originalCommand: String
    public let action: JarvisAction
    public let approval: ApprovalRequirement

    public init(originalCommand: String, action: JarvisAction, approval: ApprovalRequirement) {
        self.originalCommand = originalCommand
        self.action = action
        self.approval = approval
    }
}
