import Testing
@testable import AgentMotion

@Suite("Head gesture detector")
struct HeadGestureDetectorTests {
    @Test("A deliberate left-right motion produces one shake")
    func shake() {
        var detector = HeadGestureDetector()
        #expect(detector.process(pose: .init(yaw: 0, pitch: 0, roll: 0), timestamp: 0) == nil)
        #expect(detector.process(pose: .init(yaw: 0.34, pitch: 0, roll: 0), timestamp: 0.2) == nil)
        #expect(detector.process(pose: .init(yaw: -0.27, pitch: 0, roll: 0), timestamp: 0.55) == .shake)
        #expect(detector.process(pose: .init(yaw: 0.4, pitch: 0, roll: 0), timestamp: 0.7) == nil)
    }

    @Test("A down-up motion produces a nod")
    func nod() {
        var detector = HeadGestureDetector()
        #expect(detector.process(pose: .init(yaw: 0, pitch: 0, roll: 0), timestamp: 0) == nil)
        #expect(detector.process(pose: .init(yaw: 0, pitch: -0.28, roll: 0), timestamp: 0.25) == nil)
        #expect(detector.process(pose: .init(yaw: 0, pitch: 0.16, roll: 0), timestamp: 0.6) == .nod)
    }

    @Test("Slow movement outside the timing window is ignored")
    func expiredMovement() {
        var detector = HeadGestureDetector()
        _ = detector.process(pose: .init(yaw: 0, pitch: 0, roll: 0), timestamp: 0)
        _ = detector.process(pose: .init(yaw: 0.35, pitch: 0, roll: 0), timestamp: 0.2)
        #expect(detector.process(pose: .init(yaw: -0.3, pitch: 0, roll: 0), timestamp: 1.6) == nil)
    }
}
