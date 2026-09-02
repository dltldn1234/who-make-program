public enum HeadphoneMotionState: Equatable, Sendable {
    case idle
    case unavailable
    case requestingAuthorization
    case tracking
    case denied
    case failed(String)

    public var label: String {
        switch self {
        case .idle: "AIRPODS 대기"
        case .unavailable: "AIRPODS 모션 없음"
        case .requestingAuthorization: "모션 권한 확인 중"
        case .tracking: "HEAD TRACKING"
        case .denied: "모션 권한 거부됨"
        case .failed: "모션 연결 오류"
        }
    }

    public var isTracking: Bool {
        self == .tracking
    }
}
