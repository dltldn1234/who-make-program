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

    private let particles = HolographicCodeParticle.makeCloud(count: 520)

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
                let yaw = elapsed * Double(phase.rotationSpeed) + rotation.width / 260
                let pitch = rotation.height / 360
                let spread = 1 + max(Double(dynamics.expansion), 0) * 0.62

                let projected = particles.map {
                    $0.projected(
                        yaw: yaw,
                        pitch: pitch,
                        center: center,
                        radius: radius * spread
                    )
                }.sorted { $0.depth < $1.depth }

                for particle in projected {
                    let visibility = 0.08 + pow(particle.depth, 1.9) * 0.86
                    let cold = Color(red: 0.06, green: 0.82, blue: 1)
                    let hot = Color(red: 1, green: 0.27, blue: 0.04)
                    let color = cold.mix(with: hot, by: Double(phase.thermalShift))
                    context.draw(
                        Text(particle.token)
                            .font(.system(size: particle.fontSize, weight: .semibold, design: .monospaced))
                            .foregroundStyle(color.opacity(visibility)),
                        at: particle.point,
                        anchor: .center
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
        VStack(spacing: 5) {
            Text(phase.label.uppercased())
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .tracking(2.4)
            Text(String(format: "ENERGY %03d", Int(min(max(audioLevel, 0), 1) * 100)))
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .opacity(0.52)
        }
        .foregroundStyle(phase == .thinking ? Color.orange : Color.cyan)
        .padding(.horizontal, 13)
        .padding(.vertical, 8)
        .background(.black.opacity(0.34), in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.14), lineWidth: 0.6))
        .offset(y: 54)
        .allowsHitTesting(false)
    }
}

private struct HolographicCodeParticle: Sendable {
    let token: String
    let x: Double
    let y: Double
    let z: Double

    struct Projection {
        let token: String
        let point: CGPoint
        let depth: Double
        let fontSize: Double
    }

    func projected(
        yaw: Double,
        pitch: Double,
        center: CGPoint,
        radius: Double
    ) -> Projection {
        let yawX = x * cos(yaw) - z * sin(yaw)
        let yawZ = x * sin(yaw) + z * cos(yaw)
        let pitchedY = y * cos(pitch) - yawZ * sin(pitch)
        let pitchedZ = y * sin(pitch) + yawZ * cos(pitch)
        let depth = (pitchedZ + 1) / 2
        let perspective = 0.7 + (pitchedZ + 1) * 0.18

        return Projection(
            token: token,
            point: CGPoint(
                x: center.x + yawX * radius * perspective,
                y: center.y + pitchedY * radius * perspective
            ),
            depth: depth,
            fontSize: 2.6 + pow(depth, 1.45) * 5.8
        )
    }

    static func makeCloud(count: Int) -> [Self] {
        let tokens = [
            "func", "let", "var", "async", "await", "NEURAL", "CORE", "0101",
            "{}", "[]", "<LINK>", "SWIFT", "NODE", "VOICE", "TLS", "0xAF",
            "if", "else", "return", "true", "false", "//SYS", "MATRIX", "ONLINE"
        ]

        return (0..<count).map { index in
            let sample = Double(index) + 0.5
            let phi = acos(1 - 2 * sample / Double(count))
            let theta = .pi * (1 + sqrt(5)) * sample
            return Self(
                token: tokens[index % tokens.count],
                x: sin(phi) * cos(theta),
                y: cos(phi),
                z: sin(phi) * sin(theta)
            )
        }
    }
}
