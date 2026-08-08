import Testing
@testable import AgentVoice

@Suite("Audio level meter")
struct AudioLevelMeterTests {
    @Test("Silence maps to zero")
    func silence() {
        let samples = [Float](repeating: 0, count: 64)
        let level = samples.withUnsafeBufferPointer { AudioLevelMeter.normalizedLevel(samples: $0) }
        #expect(level == 0)
    }

    @Test("Full-scale input maps to one")
    func fullScaleInput() {
        let samples = [Float](repeating: 1, count: 64)
        let level = samples.withUnsafeBufferPointer { AudioLevelMeter.normalizedLevel(samples: $0) }
        #expect(level == 1)
    }

    @Test("Input strength increases monotonically")
    func monotonicInputStrength() {
        let quiet = [Float](repeating: 0.01, count: 64)
        let loud = [Float](repeating: 0.5, count: 64)
        let quietLevel = quiet.withUnsafeBufferPointer { AudioLevelMeter.normalizedLevel(samples: $0) }
        let loudLevel = loud.withUnsafeBufferPointer { AudioLevelMeter.normalizedLevel(samples: $0) }
        #expect(quietLevel < loudLevel)
    }
}
