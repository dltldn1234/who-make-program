import Foundation

public struct CommandInterpreter: Sendable {
    public init() {}

    public func interpret(_ rawCommand: String) -> JarvisAction {
        let command = rawCommand
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if command.isEmpty || command == "도움말" || command == "help" {
            return .showHelp
        }

        if command.contains("상태") || command == "status" {
            return .showStatus
        }

        if command.contains("몇 시") || command.contains("시간") || command == "time" {
            return .tellTime
        }

        let prefixes = ["열어줘", "실행해줘", "실행해", "open "]
        for prefix in prefixes {
            if command.hasSuffix(prefix), prefix != "open " {
                let name = command.dropLast(prefix.count).trimmingCharacters(in: .whitespaces)
                if !name.isEmpty { return .openApplication(String(name)) }
            }

            if command.hasPrefix(prefix), prefix == "open " {
                let name = command.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces)
                if !name.isEmpty { return .openApplication(String(name)) }
            }
        }

        return .unknown(rawCommand)
    }
}
