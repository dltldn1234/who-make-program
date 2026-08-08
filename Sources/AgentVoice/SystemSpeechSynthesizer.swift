@preconcurrency import AVFoundation

@MainActor
public final class SystemSpeechSynthesizer: NSObject, AVSpeechSynthesizerDelegate {
    public var onFinish: (() -> Void)?

    private let synthesizer = AVSpeechSynthesizer()
    private var activeUtterance: AVSpeechUtterance?

    public override init() {
        super.init()
        synthesizer.delegate = self
    }

    public func speak(_ text: String, language: String = "ko-KR") {
        let content = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else {
            onFinish?()
            return
        }

        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: content)
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        utterance.rate = 0.47
        utterance.pitchMultiplier = 0.92
        utterance.volume = 0.92
        utterance.preUtteranceDelay = 0.08
        activeUtterance = utterance
        synthesizer.speak(utterance)
    }

    public func stop() {
        activeUtterance = nil
        synthesizer.stopSpeaking(at: .immediate)
    }

    public nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        let identifier = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in
            guard self?.activeUtterance.map(ObjectIdentifier.init) == identifier else { return }
            self?.activeUtterance = nil
            self?.onFinish?()
        }
    }

    public nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        let identifier = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in
            guard self?.activeUtterance.map(ObjectIdentifier.init) == identifier else { return }
            self?.activeUtterance = nil
            self?.onFinish?()
        }
    }
}
