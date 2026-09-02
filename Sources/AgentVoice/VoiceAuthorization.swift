@preconcurrency import AVFoundation
@preconcurrency import Speech

public enum VoiceAuthorizationStatus: Equatable, Sendable {
    case notDetermined
    case authorized
    case denied
    case restricted
}

public struct VoiceAuthorization: Equatable, Sendable {
    public let microphone: VoiceAuthorizationStatus
    public let speechRecognition: VoiceAuthorizationStatus

    public var isAuthorized: Bool {
        microphone == .authorized && speechRecognition == .authorized
    }

    public init(
        microphone: VoiceAuthorizationStatus,
        speechRecognition: VoiceAuthorizationStatus
    ) {
        self.microphone = microphone
        self.speechRecognition = speechRecognition
    }
}

public enum VoiceAuthorizationService {
    public static func current() -> VoiceAuthorization {
        VoiceAuthorization(
            microphone: microphoneStatus(AVCaptureDevice.authorizationStatus(for: .audio)),
            speechRecognition: speechStatus(SFSpeechRecognizer.authorizationStatus())
        )
    }

    public static func request() async -> VoiceAuthorization {
        let microphoneGranted = await AVCaptureDevice.requestAccess(for: .audio)
        let speechRecognition = await requestSpeechRecognition()

        return VoiceAuthorization(
            microphone: microphoneGranted ? .authorized : .denied,
            speechRecognition: speechRecognition
        )
    }

    private static func requestSpeechRecognition() async -> VoiceAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: speechStatus(status))
            }
        }
    }

    private static func microphoneStatus(
        _ status: AVAuthorizationStatus
    ) -> VoiceAuthorizationStatus {
        switch status {
        case .notDetermined: .notDetermined
        case .authorized: .authorized
        case .denied: .denied
        case .restricted: .restricted
        @unknown default: .restricted
        }
    }

    private static func speechStatus(
        _ status: SFSpeechRecognizerAuthorizationStatus
    ) -> VoiceAuthorizationStatus {
        switch status {
        case .notDetermined: .notDetermined
        case .authorized: .authorized
        case .denied: .denied
        case .restricted: .restricted
        @unknown default: .restricted
        }
    }
}
