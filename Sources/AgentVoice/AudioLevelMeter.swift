import Foundation

public enum AudioLevelMeter {
    public static func normalizedLevel(
        samples: UnsafeBufferPointer<Float>,
        noiseFloor: Float = -55
    ) -> Float {
        guard !samples.isEmpty else { return 0 }

        let sum = samples.reduce(Float.zero) { $0 + ($1 * $1) }
        let rootMeanSquare = sqrt(sum / Float(samples.count))
        let decibels = 20 * log10(max(rootMeanSquare, .leastNonzeroMagnitude))
        return min(max((decibels - noiseFloor) / -noiseFloor, 0), 1)
    }
}
