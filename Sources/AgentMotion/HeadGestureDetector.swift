import Foundation

public struct HeadGestureDetector: Sendable {
    private enum Phase: Sendable {
        case neutral
        case yawPositive(TimeInterval)
        case yawNegative(TimeInterval)
        case pitchDown(TimeInterval)
        case cooldown(TimeInterval)
    }

    private var phase: Phase = .neutral
    private var neutralYaw: Double?
    private var neutralPitch: Double?

    public init() {}

    public mutating func process(pose: HeadPose, timestamp: TimeInterval) -> HeadGesture? {
        neutralYaw = neutralYaw ?? pose.yaw
        neutralPitch = neutralPitch ?? pose.pitch

        let yaw = pose.yaw - (neutralYaw ?? pose.yaw)
        let pitch = pose.pitch - (neutralPitch ?? pose.pitch)

        if case let .cooldown(until) = phase {
            guard timestamp >= until else { return nil }
            phase = .neutral
            neutralYaw = pose.yaw
            neutralPitch = pose.pitch
            return nil
        }

        switch phase {
        case .neutral:
            if yaw > 0.28 { phase = .yawPositive(timestamp) }
            else if yaw < -0.28 { phase = .yawNegative(timestamp) }
            else if pitch < -0.22 { phase = .pitchDown(timestamp) }

        case let .yawPositive(startedAt):
            if timestamp - startedAt > 1.2 { reset(to: pose) }
            else if yaw < -0.22 { return complete(.shake, at: timestamp) }

        case let .yawNegative(startedAt):
            if timestamp - startedAt > 1.2 { reset(to: pose) }
            else if yaw > 0.22 { return complete(.shake, at: timestamp) }

        case let .pitchDown(startedAt):
            if timestamp - startedAt > 1.0 { reset(to: pose) }
            else if pitch > 0.12 { return complete(.nod, at: timestamp) }

        case .cooldown:
            break
        }

        if abs(yaw) < 0.06, abs(pitch) < 0.06 {
            neutralYaw = neutralYaw.map { $0 * 0.96 + pose.yaw * 0.04 }
            neutralPitch = neutralPitch.map { $0 * 0.96 + pose.pitch * 0.04 }
        }

        return nil
    }

    public mutating func reset() {
        phase = .neutral
        neutralYaw = nil
        neutralPitch = nil
    }

    private mutating func reset(to pose: HeadPose) {
        phase = .neutral
        neutralYaw = pose.yaw
        neutralPitch = pose.pitch
    }

    private mutating func complete(_ gesture: HeadGesture, at timestamp: TimeInterval) -> HeadGesture {
        phase = .cooldown(timestamp + 1.1)
        return gesture
    }
}
