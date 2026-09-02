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

    @Test("Thermal transitions heat faster than they cool")
    func asymmetricThermalResponse() {
        var heating = HolographicCoreTransitionState()
        heating.advance(toward: .thinking, targetEnergy: 1, deltaTime: 0.1, reduceMotion: false)

        var cooling = HolographicCoreTransitionState()
        cooling.advance(toward: .thinking, targetEnergy: 1, deltaTime: 1, reduceMotion: true)
        cooling.advance(toward: .idle, targetEnergy: 0, deltaTime: 0.1, reduceMotion: false)

        #expect(heating.thermal > 0.4)
        #expect(cooling.thermal > 0.8)
    }

    @Test("Reduce Motion settles reactor state immediately")
    func reducedMotionSettling() {
        var state = HolographicCoreTransitionState()
        state.advance(toward: .speaking, targetEnergy: 0.72, deltaTime: 0, reduceMotion: true)

        #expect(state.thermal == HolographicCorePhase.speaking.thermalShift)
        #expect(state.energy == 0.72)
        #expect(state.turbulence == HolographicCorePhase.speaking.turbulence)
    }
}
