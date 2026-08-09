public enum HeadGesture: String, Equatable, Sendable {
    case nod
    case shake
}

public struct HeadPose: Equatable, Sendable {
    public let yaw: Double
    public let pitch: Double
    public let roll: Double

    public init(yaw: Double, pitch: Double, roll: Double) {
        self.yaw = yaw
        self.pitch = pitch
        self.roll = roll
    }
}
