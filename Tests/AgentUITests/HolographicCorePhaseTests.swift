import Testing
@testable import AgentUI

@Suite("Holographic core dynamics")
struct HolographicCorePhaseTests {
    @Test("Thinking produces the fastest and hottest core")
    func thinkingProfile() {
        #expect(HolographicCorePhase.thinking.rotationSpeed > HolographicCorePhase.speaking.rotationSpeed)
        #expect(HolographicCorePhase.thinking.thermalShift == 1)
    }

    @Test("Microphone energy is clamped before driving the core")
    func audioClamping() {
        let dynamics = HolographicCoreDynamics(phase: .listening, audioLevel: 4, gestureScale: 1)

        #expect(dynamics.energy == 1)
        #expect(dynamics.scale > 1)
    }

    @Test("Magnification remains inside the supported interaction range")
    func gestureClamping() {
        let compressed = HolographicCoreDynamics(phase: .idle, audioLevel: 0, gestureScale: 0.1)
        let expanded = HolographicCoreDynamics(phase: .idle, audioLevel: 0, gestureScale: 9)

        #expect(compressed.expansion < 0)
        #expect(expanded.expansion == 1)
    }
}
