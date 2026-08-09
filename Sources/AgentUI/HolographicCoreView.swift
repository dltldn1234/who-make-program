import SwiftUI

struct HolographicCoreView: View {
    let phase: HolographicCorePhase
    let audioLevel: Float

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var magnification = 1.0
    @State private var settledMagnification = 1.0
    @State private var rotation = CGSize.zero
    @State private var settledRotation = CGSize.zero

    var body: some View {
        ZStack {
#if os(macOS)
            MetalHolographicCoreView(
                phase: phase,
                audioLevel: audioLevel,
                expansion: magnification,
                rotation: rotation,
                reduceMotion: reduceMotion
            )
#endif
            HolographicCodeParticleLayer(
                phase: phase,
                audioLevel: audioLevel,
                magnification: magnification,
                rotation: rotation,
                reduceMotion: reduceMotion
            )
            CoreStatusReticle(phase: phase, audioLevel: audioLevel)
        }
        .contentShape(Rectangle())
        .gesture(rotationGesture)
        .simultaneousGesture(magnificationGesture)
        .onTapGesture(count: 2, perform: resetInteraction)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("코드 입자와 에너지로 이루어진 홀로그램 에이전트 코어")
        .accessibilityValue(phase.label)
        .help("드래그하여 회전 · 트랙패드 확대/축소 · 이중 클릭으로 초기화")
    }

    private var rotationGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                rotation = CGSize(
                    width: settledRotation.width + value.translation.width,
                    height: settledRotation.height + value.translation.height
                )
            }
            .onEnded { _ in
                settledRotation = rotation
            }
    }

    private var magnificationGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                magnification = min(max(settledMagnification * value.magnification, 0.72), 2.4)
            }
            .onEnded { _ in
                settledMagnification = magnification
            }
    }

    private func resetInteraction() {
        withAnimation(reduceMotion ? nil : .spring(duration: 0.55, bounce: 0.16)) {
            magnification = 1
            settledMagnification = 1
            rotation = .zero
            settledRotation = .zero
        }
    }
}

private struct HolographicCodeParticleLayer: View {
    let phase: HolographicCorePhase
    let audioLevel: Float
    let magnification: Double
    let rotation: CGSize
    let reduceMotion: Bool

    private let sparks = ReactorSpark.makeField(count: 220)

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 1 : 1 / 30)) { timeline in
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let dynamics = HolographicCoreDynamics(
                    phase: phase,
                    audioLevel: audioLevel,
                    gestureScale: magnification
                )
                let radius = min(size.width, size.height) * 0.285 * Double(dynamics.scale)
                let elapsed = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                let spread = 1 + max(Double(dynamics.expansion), 0) * 0.62
                let rotationOffset = rotation.width / 520

                for spark in sparks {
                    let progress = spark.progress(at: elapsed, energy: Double(dynamics.energy))
                    let angle = spark.angle + rotationOffset
                    let travel = radius * (0.98 + spark.reach * progress * spread)
                    let point = CGPoint(
                        x: center.x + cos(angle) * travel,
                        y: center.y + sin(angle) * travel
                    )
                    let fade = pow(1 - progress, 1.65)
                    let visibility = spark.brightness * fade
                    let cold = Color(red: 0.06, green: 0.82, blue: 1)
                    let hot = Color(red: 1, green: 0.27, blue: 0.04)
                    let color = cold.mix(with: hot, by: Double(phase.thermalShift))
                    let length = 2.2 + spark.length * (1 + Double(dynamics.energy) * 1.8)
                    var streak = Path()
                    streak.move(to: point)
                    streak.addLine(to: CGPoint(
                        x: point.x + cos(angle) * length,
                        y: point.y + sin(angle) * length
                    ))
                    context.stroke(
                        streak,
                        with: .color(color.opacity(visibility)),
                        lineWidth: 0.45 + spark.width
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private struct CoreStatusReticle: View {
    let phase: HolographicCorePhase
    let audioLevel: Float

    var body: some View {
        Text("\(phase.label.uppercased())  ·  \(String(format: "%03d", Int(min(max(audioLevel, 0), 1) * 100)))")
            .font(.system(size: 8, weight: .semibold, design: .monospaced))
            .tracking(1.6)
        .foregroundStyle(phase == .thinking ? Color.orange : Color.cyan)
        .opacity(0.7)
        .offset(y: 74)
        .allowsHitTesting(false)
    }
}

private struct ReactorSpark: Sendable {
    let angle: Double
    let reach: Double
    let speed: Double
    let phase: Double
    let length: Double
    let width: Double
    let brightness: Double

    func progress(at time: TimeInterval, energy: Double) -> Double {
        let rate = speed * (0.55 + energy * 1.25)
        return (time * rate + phase).truncatingRemainder(dividingBy: 1)
    }

    static func makeField(count: Int) -> [Self] {
        return (0..<count).map { index in
            let seed = Double(index) + 0.5
            let angle = seed * .pi * (3 - sqrt(5))
            let variation = abs(sin(seed * 91.733))
            let secondary = abs(sin(seed * 47.117 + 0.7))
            return Self(
                angle: angle,
                reach: 0.18 + variation * 0.72,
                speed: 0.12 + secondary * 0.34,
                phase: variation,
                length: 1.5 + variation * 6.5,
                width: 0.2 + secondary * 0.75,
                brightness: 0.08 + variation * 0.48
            )
        }
    }
}
