import Foundation

public enum WakeSignal: Equatable, Sendable {
    case clap
    case keyword(command: String?)
}

public struct WakeSignalDetector: Sendable {
    private let wakeWords = ["자비스", "jarvis"]
    private var previousLevel: Float = 0
    private var armedForClap = true
    private var lastSignalAt: TimeInterval = -.infinity

    public init() {}

    public mutating func observeAudioLevel(
        _ level: Float,
        at timestamp: TimeInterval = ProcessInfo.processInfo.systemUptime
    ) -> WakeSignal? {
        let normalized = min(max(level, 0), 1)
        defer { previousLevel = normalized }

        if normalized < 0.16 {
            armedForClap = true
        }

        let isSharpTransient = armedForClap && previousLevel < 0.22 && normalized >= 0.78
        guard isSharpTransient, timestamp - lastSignalAt >= 1.25 else { return nil }

        armedForClap = false
        lastSignalAt = timestamp
        return .clap
    }

    public mutating func observeTranscript(
        _ transcript: String,
        at timestamp: TimeInterval = ProcessInfo.processInfo.systemUptime
    ) -> WakeSignal? {
        let normalized = transcript
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard timestamp - lastSignalAt >= 1.25 else { return nil }
        guard let match = wakeWords.compactMap({ word -> Range<String.Index>? in
            normalized.range(of: word)
        }).min(by: { $0.lowerBound < $1.lowerBound }) else {
            return nil
        }

        let suffix = normalized[match.upperBound...]
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        lastSignalAt = timestamp
        return .keyword(command: suffix.isEmpty ? nil : suffix)
    }

    public mutating func reset() {
        previousLevel = 0
        armedForClap = true
        lastSignalAt = -.infinity
    }
}
