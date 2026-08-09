import Foundation

public enum HolographicCorePhase: String, CaseIterable, Identifiable, Sendable {
    case idle
    case listening
    case thinking
    case speaking

    public var id: Self { self }

    public var label: String {
        switch self {
        case .idle: "대기"
        case .listening: "듣는 중"
        case .thinking: "분석 중"
        case .speaking: "응답 중"
        }
    }

    var rotationSpeed: Float {
        switch self {
        case .idle: 0.18
        case .listening: 0.32
        case .thinking: 1.15
        case .speaking: 0.48
        }
    }

    var pulseStrength: Float {
        switch self {
        case .idle: 0.04
        case .listening: 0.15
        case .thinking: 0.09
        case .speaking: 0.2
        }
    }

    var thermalShift: Float {
        switch self {
        case .idle: 0
        case .listening: 0.08
        case .thinking: 1
        case .speaking: 0.42
        }
    }

    var turbulence: Float {
        switch self {
        case .idle: 0.18
        case .listening: 0.42
        case .thinking: 0.9
        case .speaking: 0.58
        }
    }
}

struct HolographicCoreDynamics: Equatable, Sendable {
    let scale: Float
    let energy: Float
    let expansion: Float

    init(phase: HolographicCorePhase, audioLevel: Float, gestureScale: Double) {
        let normalizedAudio = min(max(audioLevel, 0), 1)
        let normalizedGesture = Float(min(max(gestureScale, 0.72), 2.4))
        energy = min(1, phase.pulseStrength + normalizedAudio * 0.85)
        expansion = min(1, (normalizedGesture - 1) / 1.4)
        scale = 1 + energy * 0.08 + max(expansion, 0) * 0.16
    }
}
