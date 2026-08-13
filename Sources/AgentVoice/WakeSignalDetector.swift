import Foundation

public enum WakeSignal: Equatable, Sendable {
    case clap
    case keyword(command: String?)
}

public struct WakeSignalDetector: Sendable {
    private let wakeWords = ["자비스", "jarvis"]
    private var previousLevel: Float = 0
    private var armedForClap = true
    private var clapCandidateAt: TimeInterval?
    private var clapPeak: Float = 0
    private var lastSignalAt: TimeInterval = -.infinity

    public init() {}

    public mutating func observeAudioLevel(
        _ level: Float,
        at timestamp: TimeInterval = ProcessInfo.processInfo.systemUptime
    ) -> WakeSignal? {
        let normalized = min(max(level, 0), 1)
        let quietThreshold: Float = 0.18
        let onsetThreshold: Float = 0.24
        let peakThreshold: Float = 0.42

        if normalized < quietThreshold {
            armedForClap = true
        }

        if let candidateAt = clapCandidateAt {
            clapPeak = max(clapPeak, normalized)
            let elapsed = timestamp - candidateAt
            let hasReleased = normalized <= clapPeak * 0.72
            let isClap = elapsed <= 0.18 && clapPeak >= peakThreshold && hasReleased
            if isClap, timestamp - lastSignalAt >= 1.25 {
                clapCandidateAt = nil
                lastSignalAt = timestamp
                previousLevel = normalized
                return .clap
            }
            if elapsed > 0.24 {
                clapCandidateAt = nil
                clapPeak = 0
            }
        }

        if armedForClap && clapCandidateAt == nil,
           previousLevel < onsetThreshold,
           normalized >= peakThreshold {
            clapCandidateAt = timestamp
            clapPeak = normalized
            armedForClap = false
        }

        previousLevel = normalized
        return nil
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
        clapCandidateAt = nil
        clapPeak = 0
        lastSignalAt = -.infinity
    }
}
