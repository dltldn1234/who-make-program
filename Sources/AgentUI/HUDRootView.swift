import SwiftUI
import JarvisCore

public struct HUDRootView: View {
    @State private var mode: CoreMode = .idle
    @State private var command = ""
    @State private var response = "시스템 준비 완료"
    @State private var pendingCommand: PreparedCommand?
    @State private var showingApproval = false

    private let engine = JarvisEngine(executor: MacActionExecutor())

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

                CodeSphere(mode: mode)
                    .frame(
                        width: min(geometry.size.width * 0.68, geometry.size.height * 0.84),
                        height: min(geometry.size.width * 0.68, geometry.size.height * 0.84)
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
    }

    private var topBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("AGENT // HOLOGRAPHIC CORE")
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                Text("LOCAL SYSTEM · SECURE CHANNEL")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.cyan.opacity(0.55))
            }
            Spacer()
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
            ForEach(CoreMode.allCases) { item in
                Button(item.label) { mode = item }
                    .buttonStyle(HUDButtonStyle(selected: mode == item))
            }
        }
    }

    private var commandConsole: some View {
        VStack(spacing: 10) {
            Text(response)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.cyan.opacity(0.78))
                .lineLimit(2)
                .frame(maxWidth: 620, minHeight: 18)

            HStack(spacing: 10) {
                TextField("명령 입력 · 예: Xcode 열어줘", text: $command)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, design: .monospaced))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .background(.black.opacity(0.35), in: Capsule())
                    .overlay(Capsule().stroke(.cyan.opacity(0.38)))
                    .onSubmit(submitCommand)

                Button("EXECUTE", action: submitCommand)
                    .buttonStyle(HUDButtonStyle(selected: true))
                    .disabled(command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .frame(maxWidth: 700)
        }
    }

    private func submitCommand() {
        let submitted = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !submitted.isEmpty else { return }

        command = ""
        mode = .thinking
        response = "명령 분석 중 · \(submitted)"

        Task {
            let prepared = await engine.prepare(submitted)
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

    private func execute(_ prepared: PreparedCommand, approved: Bool) {
        pendingCommand = nil
        mode = approved ? .thinking : .idle

        Task {
            let result = await engine.execute(prepared, approved: approved)
            response = result.message
            mode = result.succeeded ? .speaking : .idle

            try? await Task.sleep(for: .seconds(1.4))
            if mode == .speaking { mode = .idle }
        }
    }
}

private enum CoreMode: String, CaseIterable, Identifiable {
    case idle, listening, thinking, speaking

    var id: Self { self }

    var label: String {
        switch self {
        case .idle: "대기"
        case .listening: "듣는 중"
        case .thinking: "분석 중"
        case .speaking: "응답 중"
        }
    }

    var speed: Double {
        switch self {
        case .idle: 0.12
        case .listening: 0.22
        case .thinking: 0.75
        case .speaking: 0.3
        }
    }

    var pulse: Double {
        switch self {
        case .idle: 0.02
        case .listening: 0.08
        case .thinking: 0.04
        case .speaking: 0.11
        }
    }
}

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

private struct CodeSphere: View {
    let mode: CoreMode
    private let particles = CodeParticle.makeCloud(count: 1_120)

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let baseRadius = min(size.width, size.height) * 0.39
                let pulse = 1 + sin(time * (mode == .speaking ? 7 : 2.2)) * mode.pulse
                let angle = time * mode.speed

                drawGlow(in: &context, center: center, radius: baseRadius * pulse)
                drawEnergyShell(in: &context, center: center, radius: baseRadius, time: time)
                drawRings(in: &context, center: center, radius: baseRadius, time: time)

                let projected = particles.map { particle in
                    particle.projected(rotation: angle, center: center, radius: baseRadius * pulse)
                }.sorted { $0.depth < $1.depth }

                for particle in projected {
                    let depthLight = 0.08 + particle.depth * 0.88
                    let text = Text(particle.token)
                        .font(.system(size: particle.fontSize, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.cyan.opacity(depthLight))
                    context.draw(text, at: particle.point, anchor: .center)
                }

                let core = Path(ellipseIn: CGRect(
                    x: center.x - 18, y: center.y - 18,
                    width: 36, height: 36
                ))
                context.fill(core, with: .radialGradient(
                    Gradient(colors: [.white, .cyan, .cyan.opacity(0)]),
                    center: center,
                    startRadius: 0,
                    endRadius: 24
                ))

                let status = Text(mode.label.uppercased())
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.92))
                context.draw(status, at: CGPoint(x: center.x, y: center.y + 42), anchor: .center)
            }
        }
        .accessibilityLabel("코드 입자로 이루어진 홀로그램 에이전트 코어")
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
            let inset = Double(index) * 3.5
            let shellRadius = radius + 7 - inset
            let rect = CGRect(
                x: center.x - shellRadius,
                y: center.y - shellRadius,
                width: shellRadius * 2,
                height: shellRadius * 2
            )
            context.stroke(
                Path(ellipseIn: rect),
                with: .color(.cyan.opacity(0.2 - Double(index) * 0.025)),
                style: StrokeStyle(
                    lineWidth: index == 0 ? 2.2 : 0.7,
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
            let ringRadius = radius * (1.08 + Double(index) * 0.08)
            let rect = CGRect(
                x: center.x - ringRadius,
                y: center.y - ringRadius * 0.36,
                width: ringRadius * 2,
                height: ringRadius * 0.72
            )
            var ring = Path(ellipseIn: rect)
            let dashPhase = time * Double(index + 1) * 12
            context.stroke(
                ring,
                with: .color(.cyan.opacity(0.34 - Double(index) * 0.06)),
                style: StrokeStyle(lineWidth: 1.2, dash: [3, 8], dashPhase: dashPhase)
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
            fontSize: 2.4 + (rotatedZ + 1) * 1.9
        )
    }

    static func makeCloud(count: Int) -> [CodeParticle] {
        let tokens = [
            "func", "let", "var", "async", "await", "AI", "CORE", "0101",
            "{}", "[]", "<>__", "swift", "node", "voice", "secure", "0xAF",
            "if", "else", "return", "true", "false", "//", "SYS", "LINK"
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
