import Foundation

#if os(macOS)
import AppKit

public struct MacActionExecutor: JarvisActionExecuting {
    public init() {}

    public func execute(_ action: JarvisAction) async -> JarvisResponse {
        switch action {
        case .showHelp:
            return JarvisResponse(
                message: "사용 가능한 명령: 도움말, 상태, 시간, '[앱 이름] 열어줘'",
                succeeded: true
            )
        case .showStatus:
            return JarvisResponse(message: "자비스 코어가 정상 작동 중입니다.", succeeded: true)
        case .tellTime:
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "ko_KR")
            formatter.dateFormat = "a h시 m분"
            return JarvisResponse(message: "현재 시간은 \(formatter.string(from: Date()))입니다.", succeeded: true)
        case let .openApplication(name):
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: name)
                ?? NSWorkspace.shared.urlForApplication(toOpen: URL(fileURLWithPath: "/Applications/\(name).app")) else {
                return JarvisResponse(message: "\(name) 앱을 찾지 못했습니다.", succeeded: false)
            }

            do {
                try await NSWorkspace.shared.openApplication(at: url, configuration: .init())
                return JarvisResponse(message: "\(name) 앱을 실행했습니다.", succeeded: true)
            } catch {
                return JarvisResponse(message: "앱 실행에 실패했습니다: \(error.localizedDescription)", succeeded: false)
            }
        case let .unknown(command):
            return JarvisResponse(message: "아직 이해하지 못한 명령입니다: \(command)", succeeded: false)
        }
    }
}
#endif
