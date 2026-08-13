import Testing
@testable import AgentVoice

@Suite("Jarvis wake signal detection")
struct WakeSignalDetectorTests {
    @Test("A sharp audio transient wakes the agent once")
    func clapTransient() {
        var detector = WakeSignalDetector()

        #expect(detector.observeAudioLevel(0.08, at: 1) == nil)
        #expect(detector.observeAudioLevel(0.56, at: 1.05) == nil)
        #expect(detector.observeAudioLevel(0.30, at: 1.08) == .clap)
    }

    @Test("Ambient loudness without a quiet onset is not a clap")
    func sustainedNoise() {
        var detector = WakeSignalDetector()

        #expect(detector.observeAudioLevel(0.42, at: 1) == nil)
        #expect(detector.observeAudioLevel(0.56, at: 1.1) == nil)
        #expect(detector.observeAudioLevel(0.52, at: 1.16) == nil)
        #expect(detector.observeAudioLevel(0.49, at: 1.22) == nil)
    }

    @Test("Korean wake word preserves a trailing command")
    func koreanWakeWord() {
        var detector = WakeSignalDetector()

        #expect(
            detector.observeTranscript("자비스, Xcode 열어줘", at: 2)
                == .keyword(command: "xcode 열어줘")
        )
    }

    @Test("English wake word can wake without a command")
    func englishWakeWord() {
        var detector = WakeSignalDetector()

        #expect(detector.observeTranscript("Jarvis", at: 2) == .keyword(command: nil))
    }

    @Test("Wake signals are debounced")
    func cooldown() {
        var detector = WakeSignalDetector()

        #expect(detector.observeTranscript("자비스", at: 2) != nil)
        #expect(detector.observeTranscript("자비스 시간 알려줘", at: 2.4) == nil)
        #expect(detector.observeTranscript("자비스 시간 알려줘", at: 3.4) != nil)
    }
}
