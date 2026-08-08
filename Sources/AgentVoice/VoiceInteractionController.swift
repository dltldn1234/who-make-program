import Combine
import Foundation

@MainActor
public final class VoiceInteractionController: ObservableObject {
    @Published public private(set) var state: VoiceInteractionState = .idle
    @Published public private(set) var transcript = ""
    @Published public private(set) var audioLevel: Float = 0
    @Published public private(set) var authorization = VoiceAuthorizationService.current()

    public var onFinalTranscript: ((String) -> Void)?

    private let recognizer: LiveSpeechRecognizer
    private let synthesizer: SystemSpeechSynthesizer
    private var deliveredTranscript = false

    public init(
        recognizer: LiveSpeechRecognizer = LiveSpeechRecognizer(),
        synthesizer: SystemSpeechSynthesizer = SystemSpeechSynthesizer()
    ) {
        self.recognizer = recognizer
        self.synthesizer = synthesizer
        bindServices()
    }

    public func toggleListening() {
        if state.isListening {
            stopListening(submitTranscript: true)
        } else {
            Task { await startListening() }
        }
    }

    public func startListening() async {
        synthesizer.stop()
        transcript = ""
        audioLevel = 0
        deliveredTranscript = false

        authorization = VoiceAuthorizationService.current()
        if !authorization.isAuthorized {
            state = .requestingPermission
            authorization = await VoiceAuthorizationService.request()
        }

        guard authorization.isAuthorized else {
            state = .failed("마이크와 음성 인식 권한을 허용해 주세요.")
            return
        }

        do {
            try recognizer.start()
            state = .listening
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    public func stopListening(submitTranscript: Bool = false) {
        recognizer.stop()
        audioLevel = 0

        if submitTranscript {
            deliverTranscriptIfNeeded()
        } else if state.isListening {
            state = .idle
        }
    }

    public func speak(_ response: String) {
        recognizer.stop()
        audioLevel = 0
        state = .speaking
        synthesizer.speak(response)
    }

    public func reset() {
        recognizer.stop()
        synthesizer.stop()
        transcript = ""
        audioLevel = 0
        state = .idle
    }

    private func bindServices() {
        recognizer.onTranscript = { [weak self] transcript, isFinal in
            guard let self else { return }
            self.transcript = transcript

            if isFinal {
                self.deliverTranscriptIfNeeded()
            }
        }

        recognizer.onAudioLevel = { [weak self] level in
            self?.audioLevel = level
        }

        recognizer.onFailure = { [weak self] message in
            guard let self, self.state.isListening else { return }
            self.audioLevel = 0
            self.state = .failed(message)
        }

        synthesizer.onFinish = { [weak self] in
            guard let self, self.state == .speaking else { return }
            self.state = .idle
        }
    }

    private func deliverTranscriptIfNeeded() {
        let finalTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !deliveredTranscript, !finalTranscript.isEmpty else {
            if finalTranscript.isEmpty {
                state = .idle
            }
            return
        }

        deliveredTranscript = true
        state = .processing
        onFinalTranscript?(finalTranscript)
    }
}
