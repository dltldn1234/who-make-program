import Foundation

public enum AgentLinkPairingPayload {
    public static func encode(code: String) -> String? {
        guard isValid(code) else { return nil }
        return "agent-link://pair?code=\(code)"
    }

    public static func decode(_ payload: String) -> String? {
        guard let components = URLComponents(string: payload),
              components.scheme == "agent-link",
              components.host == "pair",
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
              isValid(code) else {
            return nil
        }
        return code
    }

    private static func isValid(_ code: String) -> Bool {
        code.count == 6 && code.allSatisfy(\.isNumber)
    }
}
