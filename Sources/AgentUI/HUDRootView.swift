import SwiftUI
import JarvisCore
import AgentLink
import AgentVoice
import AgentMotion
import AgentIntelligence
#if os(macOS)
import CoreImage.CIFilterBuiltins
import AppKit
#endif

public struct HUDRootView: View {
    @State private var mode: HolographicCorePhase = .idle
    @State private var command = ""
    @State private var response = "시스템 준비 완료"
    @State private var showingTextFallback = false
    @State private var pendingCommand: PreparedCommand?
    @State private var showingApproval = false
    @State private var showingPairingQR = false
    @StateObject private var voice = VoiceInteractionController()
    @StateObject private var motion = HeadphoneMotionController()
    @StateObject private var link = AgentLinkServer(name: Host.current().localizedName ?? "Agent Mac")

    private let engine = JarvisEngine(executor: MacActionExecutor())
    private let intelligence = OpenAIConversationClient()

    public init() {}

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(red: 0.002, green: 0.012, blue: 0.026)
                    .ignoresSafeArea()

                CircuitBackground()
                    .opacity(0.48)

                HStack(spacing: 0) {
                    TelemetryPanel(alignment: .leading)
                        .frame(width: 170)

                    Spacer(minLength: 0)

                    TelemetryPanel(alignment: .trailing)
                        .frame(width: 170)
                }
                .padding(.horizontal, 24)
                .padding(.top, 90)
                .padding(.bottom, 130)

                HolographicCoreView(phase: mode, audioLevel: voice.audioLevel)
                    .frame(
                        width: min(geometry.size.width * 0.76, geometry.size.height * 0.92),
                        height: min(geometry.size.width * 0.76, geometry.size.height * 0.92)
                    )
                    .offset(y: -14)

                VStack(spacing: 0) {
                    topBar
                    Spacer()
                    commandConsole
                        .padding(.bottom, 12)
                    modePicker
                        .padding(.bottom, 18)
                }
            }
        }
        .foregroundStyle(.cyan)
        .onAppear {
            voice.onFinalTranscript = { transcript in
                submitCommand(transcript)
            }
            voice.onWakeSignal = { signal in
                response = signal == .clap ? "박수 감지 · JARVIS 기동" : "JARVIS 호출 감지 · 명령 채널 개방"
                mode = .listening
            }
            motion.onGesture = handleHeadGesture
            link.onCommand = { remoteCommand in
                submitCommand(remoteCommand)
            }
            link.start()
            Task { await voice.enableWakeMode() }
        }
        .onDisappear(perform: link.stop)
        .onChange(of: voice.state) { _, state in
            synchronizeVoiceState(state)
        }
        .alert("명령 실행 승인", isPresented: $showingApproval, presenting: pendingCommand) { prepared in
            Button("취소", role: .cancel) {
                execute(prepared, approved: false)
            }
            Button("실행") {
                execute(prepared, approved: true)
            }
        } message: { prepared in
            if case let .userConfirmation(reason) = prepared.approval {
                Text(reason)
            }
        }
        .sheet(isPresented: $showingPairingQR) {
            if case let .advertising(code) = link.state {
                PairingQRCodeView(code: code)
            }
        }
    }

    private var topBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("AGENT // HOLOGRAPHIC CORE")
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                Text("TLS 1.3 LINK · APPROVAL GATED")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.cyan.opacity(0.55))
            }
            Spacer()
            if case let .advertising(code) = link.state {
                Button {
                    showingPairingQR = true
                } label: {
                    Label("PAIR \(code)", systemImage: "qrcode")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(.cyan.opacity(0.08), in: Capsule())
                        .overlay(Capsule().stroke(.cyan.opacity(0.35)))
                }
                .buttonStyle(.plain)
                .help("QR 코드를 열어 iPhone Agent와 페어링")
            } else if case let .connected(peerName) = link.state {
                Label(peerName, systemImage: "iphone.radiowaves.left.and.right")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.green)
            }
            Button(action: motion.toggle) {
                HStack(spacing: 6) {
                    Image(systemName: "airpodspro")
                    Text(motion.state.label)
                }
            }
            .buttonStyle(HUDButtonStyle(selected: motion.state.isTracking))
            .help("AirPods 머리 움직임 제어")

            Text(mode.label.uppercased())
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.cyan.opacity(0.1), in: Capsule())
                .overlay(Capsule().stroke(.cyan.opacity(0.5)))
        }
        .padding(24)
    }

    private var modePicker: some View {
        HStack(spacing: 8) {
            ForEach(HolographicCorePhase.allCases) { item in
                Button(item.label) { mode = item }
                    .buttonStyle(HUDButtonStyle(selected: mode == item))
            }
        }
    }

    private var commandConsole: some View {
        VStack(spacing: 10) {
            if !voice.transcript.isEmpty || voice.state.isListening {
                HStack(spacing: 10) {
                    Circle()
                        .fill(.cyan)
                        .frame(width: 6, height: 6)
                        .shadow(color: .cyan, radius: 5)

                    Text(voice.transcript.isEmpty ? "음성을 기다리는 중..." : voice.transcript)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.cyan.opacity(0.72))
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    AudioEnergyBar(level: voice.audioLevel)
                }
                .frame(maxWidth: 700)
            }

            Text(response)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.cyan.opacity(0.78))
                .lineLimit(2)
                .frame(maxWidth: 620, minHeight: 18)

            HStack(spacing: 10) {
                Button(action: voice.toggleListening) {
                    Label(
                        voice.state.isListening ? "말하기 종료" : "말로 명령하기",
                        systemImage: voice.state.isListening ? "stop.fill" : "mic.fill"
                    )
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .frame(minWidth: 154)
                }
                .buttonStyle(HUDButtonStyle(selected: voice.state.isListening))
                .help(voice.state.isListening ? "음성 입력 종료" : "음성으로 자비스에게 명령")

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showingTextFallback.toggle()
                    }
                } label: {
                    Image(systemName: showingTextFallback ? "keyboard.chevron.compact.down" : "keyboard")
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(HUDButtonStyle(selected: showingTextFallback))
                .help(showingTextFallback ? "텍스트 입력 닫기" : "텍스트 입력 fallback 열기")
            }
            .frame(maxWidth: 700)

            if showingTextFallback {
                HStack(spacing: 10) {
                    TextField("텍스트 fallback · 예: Xcode 열어줘", text: $command)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, design: .monospaced))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)
                        .background(.black.opacity(0.35), in: Capsule())
                        .overlay(Capsule().stroke(.cyan.opacity(0.38)))
                        .onSubmit { submitCommand() }

                    Button("EXECUTE") { submitCommand() }
                        .buttonStyle(HUDButtonStyle(selected: true))
                        .disabled(command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .frame(maxWidth: 700)
            }
        }
    }

    private func submitCommand(_ voiceCommand: String? = nil) {
        let submitted = (voiceCommand ?? command).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !submitted.isEmpty else { return }

        command = ""
        mode = .thinking
        response = "명령 분석 중 · \(submitted)"

        Task {
            let prepared = await engine.prepare(submitted)
            if case .unknown = prepared.action {
                await answerWithAI(submitted)
                return
            }
            switch prepared.approval {
            case .automatic:
                execute(prepared, approved: true)
            case .userConfirmation:
                pendingCommand = prepared
                showingApproval = true
                mode = .idle
                response = "사용자 승인을 기다리는 중"
            }
        }
    }

    @MainActor
    private func answerWithAI(_ question: String) async {
        response = "JARVIS AI가 답변을 생성하고 있습니다"
        mode = .thinking

        do {
            let answer = try await intelligence.answer(question)
            response = answer
            mode = .speaking
            voice.speak(answer)
        } catch {
            response = error.localizedDescription
            mode = .idle
            voice.speak(error.localizedDescription)
        }
    }

    private func execute(_ prepared: PreparedCommand, approved: Bool) {
        pendingCommand = nil
        mode = approved ? .thinking : .idle

        Task {
            let result = await engine.execute(prepared, approved: approved)
            response = result.message
            mode = result.succeeded ? .speaking : .idle

            if approved {
                voice.speak(result.message)
            }

            if !approved {
                try? await Task.sleep(for: .seconds(1.4))
                if mode == .speaking { mode = .idle }
            }
        }
    }

    private func synchronizeVoiceState(_ state: VoiceInteractionState) {
        switch state {
        case .idle:
            if mode == .listening || mode == .speaking {
                mode = .idle
            }
        case .wakeMonitoring:
            mode = .idle
            response = "웨이크 대기 중 · 박수를 치거나 ‘자비스’라고 부르세요"
        case .requestingPermission, .processing:
            mode = .thinking
        case .listening:
            mode = .listening
            response = "음성 명령을 듣고 있습니다"
        case .speaking:
            mode = .speaking
        case let .failed(message):
            mode = .idle
            response = message
        }
    }

    private func handleHeadGesture(_ gesture: HeadGesture) {
        guard let pendingCommand, showingApproval else {
            response = gesture == .nod ? "끄덕임 감지 · 승인 대기 명령 없음" : "좌우 움직임 감지 · 취소할 명령 없음"
            return
        }

        showingApproval = false
        switch gesture {
        case .nod:
            response = "끄덕임으로 명령 승인"
            execute(pendingCommand, approved: true)
        case .shake:
            response = "좌우 움직임으로 명령 취소"
            execute(pendingCommand, approved: false)
        }
    }
}

#if os(macOS)
private struct PairingQRCodeView: View {
    let code: String
    @Environment(\.dismiss) private var dismiss

    private var qrImage: NSImage? {
        guard let payload = AgentLinkPairingPayload.encode(code: code) else { return nil }
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(payload.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 10, y: 10)) else {
            return nil
        }
        let representation = NSCIImageRep(ciImage: output)
        let image = NSImage(size: representation.size)
        image.addRepresentation(representation)
        return image
    }

    var body: some View {
        VStack(spacing: 18) {
            Text("SECURE DEVICE LINK")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .tracking(2)
            if let qrImage {
                Image(nsImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 260, height: 260)
                    .padding(18)
                    .background(.white, in: RoundedRectangle(cornerRadius: 20))
            }
            Text("iPhone Agent에서 QR 스캔")
                .font(.system(size: 12, design: .monospaced))
            Text("PAIRING CODE  \(code)")
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundStyle(.cyan)
            Text("같은 Wi-Fi에서만 연결되며 최초 연결 후 TLS 신뢰 키가 Keychain에 저장됩니다.")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 330)
            Button("닫기", action: dismiss.callAsFunction)
                .keyboardShortcut(.cancelAction)
        }
        .padding(28)
        .frame(width: 400)
        .background(Color(red: 0.002, green: 0.012, blue: 0.026))
    }
}
#endif

private struct HUDButtonStyle: ButtonStyle {
    let selected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .foregroundStyle(selected ? Color.black : Color.cyan)
            .background(selected ? Color.cyan : Color.cyan.opacity(configuration.isPressed ? 0.18 : 0.06))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(.cyan.opacity(0.45)))
    }
}

private struct AudioEnergyBar: View {
    let level: Float

    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(0..<12, id: \.self) { index in
                let threshold = Float(index + 1) / 12

                Capsule()
                    .fill(threshold <= level ? Color.cyan : Color.cyan.opacity(0.12))
                    .frame(width: 3, height: 5 + CGFloat(index % 4) * 3)
                    .shadow(color: threshold <= level ? .cyan : .clear, radius: 3)
            }
        }
        .frame(width: 62)
        .animation(.linear(duration: 0.08), value: level)
        .accessibilityLabel("마이크 입력 세기")
        .accessibilityValue("\(Int(level * 100)) 퍼센트")
    }
}

private struct CodeSphere: View {
    let mode: HolographicCorePhase
    let audioEnergy: Float
    private let particles = CodeParticle.makeCloud(count: 640)

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let baseRadius = min(size.width, size.height) * 0.34
                let reactivePulse = mode == .listening ? Double(audioEnergy) * 0.035 : 0
                let pulse = 1 + sin(time * (mode == .speaking ? 7 : 2.2)) * Double(mode.pulseStrength) + reactivePulse
                let angle = time * Double(mode.rotationSpeed)

                drawAtmosphere(in: &context, center: center, radius: baseRadius, time: time)
                drawGlow(in: &context, center: center, radius: baseRadius * pulse)
                drawWireframe(in: &context, center: center, radius: baseRadius * pulse, time: time)
                drawEnergyShell(in: &context, center: center, radius: baseRadius, time: time)
                drawRings(in: &context, center: center, radius: baseRadius, time: time)

                let projected = particles.map { particle in
                    particle.projected(rotation: angle, center: center, radius: baseRadius * pulse)
                }.sorted { $0.depth < $1.depth }

                for particle in projected {
                    let depthLight = 0.05 + pow(particle.depth, 1.7) * 0.94
                    let text = Text(particle.token)
                        .font(.system(size: particle.fontSize, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color(red: 0.15, green: 0.9, blue: 1).opacity(depthLight))
                    context.draw(text, at: particle.point, anchor: .center)
                }

                drawEnergyWave(in: &context, center: center, radius: baseRadius, time: time)

                let coreRadius = 28 + Double(audioEnergy) * 14
                let core = Path(ellipseIn: CGRect(
                    x: center.x - coreRadius, y: center.y - coreRadius,
                    width: coreRadius * 2, height: coreRadius * 2
                ))
                context.fill(core, with: .radialGradient(
                    Gradient(stops: [
                        .init(color: .white, location: 0),
                        .init(color: .cyan, location: 0.18),
                        .init(color: .blue.opacity(0.56), location: 0.48),
                        .init(color: .clear, location: 1)
                    ]),
                    center: center,
                    startRadius: 0,
                    endRadius: coreRadius
                ))

                let status = Text(mode.label.uppercased())
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.92))
                context.draw(status, at: CGPoint(x: center.x, y: center.y + 42), anchor: .center)
            }
        }
        .accessibilityLabel("코드 입자로 이루어진 홀로그램 에이전트 코어")
    }

    private func drawAtmosphere(
        in context: inout GraphicsContext,
        center: CGPoint,
        radius: Double,
        time: Double
    ) {
        let breathing = 1 + sin(time * 1.25) * 0.025
        let haloRadius = radius * 1.48 * breathing
        let rect = CGRect(
            x: center.x - haloRadius,
            y: center.y - haloRadius,
            width: haloRadius * 2,
            height: haloRadius * 2
        )
        context.fill(Path(ellipseIn: rect), with: .radialGradient(
            Gradient(stops: [
                .init(color: .cyan.opacity(0.1), location: 0),
                .init(color: .blue.opacity(0.045), location: 0.52),
                .init(color: .cyan.opacity(0.018), location: 0.78),
                .init(color: .clear, location: 1)
            ]),
            center: center,
            startRadius: 0,
            endRadius: haloRadius
        ))
    }

    private func drawWireframe(
        in context: inout GraphicsContext,
        center: CGPoint,
        radius: Double,
        time: Double
    ) {
        for latitude in -4...4 {
            let normalized = Double(latitude) / 5
            let horizontalRadius = radius * sqrt(1 - normalized * normalized)
            let y = center.y + normalized * radius
            let rect = CGRect(
                x: center.x - horizontalRadius,
                y: y - horizontalRadius * 0.13,
                width: horizontalRadius * 2,
                height: horizontalRadius * 0.26
            )
            context.stroke(
                Path(ellipseIn: rect),
                with: .color(.cyan.opacity(latitude == 0 ? 0.32 : 0.13)),
                style: StrokeStyle(lineWidth: latitude == 0 ? 1.1 : 0.55, dash: [1.5, 5], dashPhase: time * 5)
            )
        }

        for longitude in 0..<7 {
            var layer = context
            layer.translateBy(x: center.x, y: center.y)
            layer.rotate(by: .radians(Double(longitude) * .pi / 7 + time * 0.018))
            let rect = CGRect(x: -radius * 0.27, y: -radius, width: radius * 0.54, height: radius * 2)
            layer.stroke(
                Path(ellipseIn: rect),
                with: .color(.cyan.opacity(0.14)),
                style: StrokeStyle(lineWidth: 0.65, dash: [2, 7], dashPhase: -time * 4)
            )
        }
    }

    private func drawEnergyWave(
        in context: inout GraphicsContext,
        center: CGPoint,
        radius: Double,
        time: Double
    ) {
        let energy = mode == .listening ? max(Double(audioEnergy), 0.08) : 0.08
        var wave = Path()
        let width = radius * 1.72
        let segments = 90

        for index in 0...segments {
            let progress = Double(index) / Double(segments)
            let x = center.x - width / 2 + width * progress
            let envelope = sin(progress * .pi)
            let y = center.y + sin(progress * 18 * .pi - time * 9) * energy * 23 * envelope
            if index == 0 { wave.move(to: CGPoint(x: x, y: y)) }
            else { wave.addLine(to: CGPoint(x: x, y: y)) }
        }

        var glow = context
        glow.addFilter(.blur(radius: 5))
        glow.stroke(wave, with: .color(.cyan.opacity(0.5)), lineWidth: 4)
        context.stroke(wave, with: .color(.white.opacity(0.72)), lineWidth: 0.8)
    }

    private func drawGlow(in context: inout GraphicsContext, center: CGPoint, radius: Double) {
        let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        context.fill(Path(ellipseIn: rect), with: .radialGradient(
            Gradient(stops: [
                .init(color: .cyan.opacity(0.2), location: 0),
                .init(color: .blue.opacity(0.07), location: 0.62),
                .init(color: .clear, location: 1)
            ]),
            center: center,
            startRadius: 0,
            endRadius: radius
        ))
    }

    private func drawEnergyShell(
        in context: inout GraphicsContext,
        center: CGPoint,
        radius: Double,
        time: Double
    ) {
        for index in 0..<5 {
            let inset = Double(index) * 4.5
            let shellRadius = radius + 10 - inset
            let rect = CGRect(
                x: center.x - shellRadius,
                y: center.y - shellRadius,
                width: shellRadius * 2,
                height: shellRadius * 2
            )
            context.stroke(
                Path(ellipseIn: rect),
                with: .color(.cyan.opacity(0.31 - Double(index) * 0.045)),
                style: StrokeStyle(
                    lineWidth: index == 0 ? 2.6 : 0.75,
                    dash: [2, Double(5 + index * 3)],
                    dashPhase: time * Double(index + 1) * 9
                )
            )
        }

        drawOrbitalPlane(
            in: &context,
            center: center,
            radius: radius * 1.12,
            rotation: time * 0.08,
            opacity: 0.48
        )
        drawOrbitalPlane(
            in: &context,
            center: center,
            radius: radius * 1.08,
            rotation: -0.72 + time * 0.05,
            opacity: 0.31
        )

        let scannerY = center.y + sin(time * 0.9) * radius * 0.72
        let scannerWidth = sqrt(max(0, 1 - pow((scannerY - center.y) / radius, 2))) * radius
        let scanner = Path(CGRect(
            x: center.x - scannerWidth,
            y: scannerY - 1,
            width: scannerWidth * 2,
            height: 2
        ))
        context.fill(scanner, with: .linearGradient(
            Gradient(colors: [.clear, .cyan.opacity(0.75), .white, .cyan.opacity(0.75), .clear]),
            startPoint: CGPoint(x: center.x - scannerWidth, y: scannerY),
            endPoint: CGPoint(x: center.x + scannerWidth, y: scannerY)
        ))
    }

    private func drawOrbitalPlane(
        in context: inout GraphicsContext,
        center: CGPoint,
        radius: Double,
        rotation: Double,
        opacity: Double
    ) {
        var layer = context
        layer.translateBy(x: center.x, y: center.y)
        layer.rotate(by: .radians(rotation))
        let rect = CGRect(x: -radius * 0.34, y: -radius, width: radius * 0.68, height: radius * 2)
        layer.stroke(
            Path(ellipseIn: rect),
            with: .color(.cyan.opacity(opacity)),
            style: StrokeStyle(lineWidth: 1.2, dash: [10, 7])
        )
    }

    private func drawRings(in context: inout GraphicsContext, center: CGPoint, radius: Double, time: Double) {
        for index in 0..<3 {
            let ringRadius = radius * (1.16 + Double(index) * 0.12)
            let rect = CGRect(
                x: center.x - ringRadius,
                y: center.y - ringRadius * 0.36,
                width: ringRadius * 2,
                height: ringRadius * (index == 0 ? 0.48 : 0.62)
            )
            var ring = Path(ellipseIn: rect)
            let dashPhase = time * Double(index + 1) * 12
            context.stroke(
                ring,
                with: .color(.cyan.opacity(0.48 - Double(index) * 0.09)),
                style: StrokeStyle(lineWidth: index == 0 ? 1.8 : 1.05, dash: [3, 8], dashPhase: dashPhase)
            )
            ring = Path(ellipseIn: rect.insetBy(dx: ringRadius * 0.04, dy: ringRadius * 0.014))
            context.stroke(ring, with: .color(.cyan.opacity(0.08)), lineWidth: 1)
        }
    }
}

private struct CodeParticle: Sendable {
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

    func projected(rotation: Double, center: CGPoint, radius: Double) -> Projection {
        let rotatedX = x * cos(rotation) - z * sin(rotation)
        let rotatedZ = x * sin(rotation) + z * cos(rotation)
        let perspective = 0.76 + (rotatedZ + 1) * 0.16
        return Projection(
            token: token,
            point: CGPoint(
                x: center.x + rotatedX * radius * perspective,
                y: center.y + y * radius * perspective
            ),
            depth: (rotatedZ + 1) / 2,
            fontSize: 2.8 + pow((rotatedZ + 1) / 2, 1.4) * 5.4
        )
    }

    static func makeCloud(count: Int) -> [CodeParticle] {
        let tokens = [
            "func", "let", "var", "async", "await", "NEURAL", "CORE", "0101",
            "{}", "[]", "<LINK>", "SWIFT", "NODE", "VOICE", "SECURE", "0xAF",
            "if", "else", "return", "true", "false", "//SYS", "MATRIX", "ONLINE"
        ]

        return (0..<count).map { index in
            let i = Double(index) + 0.5
            let phi = acos(1 - 2 * i / Double(count))
            let theta = .pi * (1 + sqrt(5)) * i
            return CodeParticle(
                token: tokens[index % tokens.count],
                x: sin(phi) * cos(theta),
                y: cos(phi),
                z: sin(phi) * sin(theta)
            )
        }
    }
}

private struct TelemetryPanel: View {
    let alignment: HorizontalAlignment

    private var textAlignment: TextAlignment {
        alignment == .leading ? .leading : .trailing
    }

    var body: some View {
        VStack(alignment: alignment, spacing: 18) {
            telemetryGroup(title: "CORE MATRIX", values: ["NODES  1,120", "SYNC   99.98%", "STATE  NOMINAL"])
            telemetryGroup(title: "LOCAL LINK", values: ["MAC    ONLINE", "PHONE  STANDBY", "AUDIO  READY"])
            Spacer()
            telemetryGroup(title: "SECURITY", values: ["POLICY ACTIVE", "CHANNEL LOCAL", "LEVEL  00"])
        }
        .font(.system(size: 9, weight: .medium, design: .monospaced))
        .foregroundStyle(.cyan.opacity(0.55))
    }

    private func telemetryGroup(title: String, values: [String]) -> some View {
        VStack(alignment: alignment, spacing: 5) {
            Text(title)
                .fontWeight(.bold)
                .foregroundStyle(.cyan.opacity(0.85))

            Rectangle()
                .fill(.cyan.opacity(0.4))
                .frame(width: 92, height: 1)

            ForEach(values, id: \.self) { value in
                Text(value)
            }
        }
        .multilineTextAlignment(textAlignment)
        .padding(12)
        .background(.cyan.opacity(0.025))
        .overlay {
            RoundedRectangle(cornerRadius: 4)
                .stroke(.cyan.opacity(0.13), lineWidth: 0.7)
        }
    }
}

private struct CircuitBackground: View {
    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 56
            var grid = Path()

            for x in stride(from: CGFloat.zero, through: size.width, by: step) {
                grid.move(to: CGPoint(x: x, y: 0))
                grid.addLine(to: CGPoint(x: x, y: size.height))
            }
            for y in stride(from: CGFloat.zero, through: size.height, by: step) {
                grid.move(to: CGPoint(x: 0, y: y))
                grid.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(grid, with: .color(.cyan.opacity(0.05)), lineWidth: 0.5)
        }
        .ignoresSafeArea()
    }
}
