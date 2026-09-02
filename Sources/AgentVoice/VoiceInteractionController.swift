import Combine
import Foundation

@MainActor
public final class VoiceInteractionController: ObservableObject {
    @Published public private(set) var state: VoiceInteractionState = .idle
    @Published public private(set) var transcript = ""
    @Published public private(set) var audioLevel: Float = 0
    @Published public private(set) var authorization = VoiceAuthorizationService.current()
    @Published public private(set) var wakeModeEnabled = false

    public var onFinalTranscript: ((String) -> Void)?
    public var onWakeSignal: ((WakeSignal) -> Void)?

    private let recognizer: LiveSpeechRecognizer
    private let synthesizer: SystemSpeechSynthesizer
    private var deliveredTranscript = false
    private var wakeDetector = WakeSignalDetector()

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

    public func enableWakeMode() async {
        wakeModeEnabled = true
        await startWakeMonitoring()
    }

    public func disableWakeMode() {
        wakeModeEnabled = false
        recognizer.stop()
        transcript = ""
        audioLevel = 0
        state = .idle
        wakeDetector.reset()
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
            resumeWakeMonitoring()
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
        wakeModeEnabled = false
        wakeDetector.reset()
    }

    private func bindServices() {
        recognizer.onTranscript = { [weak self] transcript, isFinal in
            guard let self else { return }
            self.transcript = transcript

            if self.state == .wakeMonitoring {
                if let signal = self.wakeDetector.observeTranscript(transcript) {
                    self.handleWakeSignal(signal)
                } else if isFinal {
                    self.restartWakeMonitoring()
                }
                return
            }

            if isFinal {
                self.deliverTranscriptIfNeeded()
            }
        }

        recognizer.onAudioLevel = { [weak self] level in
            guard let self else { return }
            self.audioLevel = level
            if self.state == .wakeMonitoring,
               let signal = self.wakeDetector.observeAudioLevel(level) {
                self.handleWakeSignal(signal)
            }
        }

        recognizer.onFailure = { [weak self] message in
            guard let self else { return }
            if self.state == .wakeMonitoring {
                self.restartWakeMonitoring()
                return
            }
            guard self.state.isListening else { return }
            self.audioLevel = 0
            self.state = .failed(message)
        }

        synthesizer.onFinish = { [weak self] in
            guard let self, self.state == .speaking else { return }
            self.resumeWakeMonitoring()
        }
    }

    private func startWakeMonitoring() async {
        authorization = VoiceAuthorizationService.current()
        if !authorization.isAuthorized {
            state = .requestingPermission
            authorization = await VoiceAuthorizationService.request()
        }

        guard wakeModeEnabled, authorization.isAuthorized else {
            if !authorization.isAuthorized {
                state = .failed("웨이크 모드를 사용하려면 마이크와 음성 인식 권한이 필요합니다.")
            }
            return
        }

        transcript = ""
        audioLevel = 0
        wakeDetector.reset()
        do {
            try recognizer.start()
            state = .wakeMonitoring
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func handleWakeSignal(_ signal: WakeSignal) {
        guard state == .wakeMonitoring else { return }
        recognizer.stop()
        transcript = ""
        audioLevel = 0
        onWakeSignal?(signal)

        if case let .keyword(command?) = signal {
            state = .processing
            onFinalTranscript?(command)
            return
        }

        state = .listening
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(180))
            await self?.startListening()
        }
    }

    private func restartWakeMonitoring() {
        guard wakeModeEnabled else { return }
        recognizer.stop()
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            await self?.startWakeMonitoring()
        }
    }

    private func resumeWakeMonitoring() {
        if wakeModeEnabled {
            restartWakeMonitoring()
        } else {
            state = .idle
        }
    }

    private func deliverTranscriptIfNeeded() {
        let finalTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !deliveredTranscript, !finalTranscript.isEmpty else {
            if finalTranscript.isEmpty {
                resumeWakeMonitoring()
            }
            return
        }

        deliveredTranscript = true
        state = .processing
        onFinalTranscript?(finalTranscript)
    }
}
