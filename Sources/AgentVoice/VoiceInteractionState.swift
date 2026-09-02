import Foundation

public enum VoiceInteractionState: Equatable, Sendable {
    case idle
    case wakeMonitoring
    case requestingPermission
    case listening
    case processing
    case speaking
    case failed(String)

    public var isListening: Bool {
        self == .listening
    }

    public var label: String {
        switch self {
        case .idle: "대기"
        case .wakeMonitoring: "웨이크 대기 중"
        case .requestingPermission: "권한 확인 중"
        case .listening: "듣는 중"
        case .processing: "음성 분석 중"
        case .speaking: "응답 중"
        case .failed: "음성 오류"
        }
    }
}
