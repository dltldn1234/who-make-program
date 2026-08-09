@preconcurrency import AVFoundation
@preconcurrency import Speech

public enum LiveSpeechRecognizerError: LocalizedError, Sendable {
    case recognizerUnavailable
    case invalidInputFormat
    case audioEngineFailure(String)

    public var errorDescription: String? {
        switch self {
        case .recognizerUnavailable:
            "현재 음성 인식 서비스를 사용할 수 없습니다."
        case .invalidInputFormat:
            "마이크 입력 형식을 확인할 수 없습니다."
        case let .audioEngineFailure(message):
            "마이크를 시작하지 못했습니다: \(message)"
        }
    }
}

@MainActor
public final class LiveSpeechRecognizer {
    public var onTranscript: ((String, Bool) -> Void)?
    public var onAudioLevel: ((Float) -> Void)?
    public var onFailure: ((String) -> Void)?

    private let audioEngine = AVAudioEngine()
    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var hasInputTap = false

    public init(localeIdentifier: String = "ko-KR") {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier))
    }

    public func start() throws {
        stop()

        guard let speechRecognizer, speechRecognizer.isAvailable else {
            throw LiveSpeechRecognizerError.recognizerUnavailable
        }

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw LiveSpeechRecognizerError.invalidInputFormat
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = false
        recognitionRequest = request

        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self else { return }

                if let result {
                    onTranscript?(result.bestTranscription.formattedString, result.isFinal)
                }

                if let error {
                    onFailure?(error.localizedDescription)
                    stop()
                } else if result?.isFinal == true {
                    stop()
                }
            }
        }

        inputNode.installTap(onBus: 0, bufferSize: 1_024, format: format) { @Sendable [weak self] buffer, _ in
            request.append(buffer)

            guard let channel = buffer.floatChannelData?.pointee else { return }
            let samples = UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength))
            let level = AudioLevelMeter.normalizedLevel(samples: samples)

            Task { @MainActor [weak self] in
                self?.onAudioLevel?(level)
            }
        }
        hasInputTap = true

        audioEngine.prepare()

        do {
            try audioEngine.start()
        } catch {
            stop()
            throw LiveSpeechRecognizerError.audioEngineFailure(error.localizedDescription)
        }
    }

    public func stop() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }

        if hasInputTap {
            audioEngine.inputNode.removeTap(onBus: 0)
            hasInputTap = false
        }
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        onAudioLevel?(0)
    }
}
