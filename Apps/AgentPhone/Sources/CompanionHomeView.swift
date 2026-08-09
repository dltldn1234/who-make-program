import AgentLink
import SwiftUI

struct CompanionHomeView: View {
    @State private var pairingCode = ""
    @State private var command = ""
    @State private var connectionState = ConnectionState.searching

    var body: some View {
        ZStack {
            Color(red: 0.002, green: 0.012, blue: 0.026)
                .ignoresSafeArea()

            VStack(spacing: 28) {
                header
                linkCore
                pairingPanel
                commandPanel
                Spacer(minLength: 0)
            }
            .padding(24)
        }
        .foregroundStyle(.cyan)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("AGENT // MOBILE LINK")
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                Text("ENCRYPTED LOCAL SESSION")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.cyan.opacity(0.55))
            }
            Spacer()
            Circle()
                .fill(connectionState.color)
                .frame(width: 8, height: 8)
                .shadow(color: connectionState.color, radius: 6)
        }
    }

    private var linkCore: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { index in
                Circle()
                    .stroke(.cyan.opacity(0.3 - Double(index) * 0.055), style: StrokeStyle(lineWidth: 1, dash: [3, 7]))
                    .frame(width: 180 - CGFloat(index * 24), height: 180 - CGFloat(index * 24))
            }
            Circle()
                .fill(.radialGradient(colors: [.white, .cyan, .blue.opacity(0.25), .clear], center: .center, startRadius: 0, endRadius: 46))
                .frame(width: 92, height: 92)
            VStack(spacing: 4) {
                Image(systemName: "macbook.and.iphone")
                    .font(.system(size: 22))
                Text(connectionState.label)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
            }
        }
        .frame(height: 190)
    }

    private var pairingPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PAIRING CODE")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
            TextField("Mac에 표시된 6자리 코드", text: $pairingCode)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .font(.system(size: 22, weight: .semibold, design: .monospaced))
                .multilineTextAlignment(.center)
                .padding(14)
                .background(.cyan.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(.cyan.opacity(0.3)))
                .onChange(of: pairingCode) { _, value in
                    pairingCode = String(value.filter(\.isNumber).prefix(6))
                }
            Button("MAC과 페어링") {
                connectionState = pairingCode.count == 6 ? .ready : .invalidCode
            }
            .buttonStyle(LinkButtonStyle())
            .disabled(pairingCode.count != 6)
        }
        .linkPanel()
    }

    private var commandPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("REMOTE COMMAND")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
            HStack {
                TextField("연결 후 명령 입력", text: $command)
                    .textFieldStyle(.plain)
                Button {
                    command = ""
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 26))
                }
                .buttonStyle(.plain)
                .disabled(connectionState != .ready || command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(14)
            .background(.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.cyan.opacity(0.2)))
        }
        .linkPanel()
    }
}

private enum ConnectionState {
    case searching
    case ready
    case invalidCode

    var label: String {
        switch self {
        case .searching: "SEARCHING FOR MAC"
        case .ready: "SECURE LINK READY"
        case .invalidCode: "INVALID CODE"
        }
    }

    var color: Color {
        switch self {
        case .searching: .orange
        case .ready: .cyan
        case .invalidCode: .red
        }
    }
}

private struct LinkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .bold, design: .monospaced))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .foregroundStyle(.black)
            .background(.cyan.opacity(configuration.isPressed ? 0.7 : 1), in: Capsule())
    }
}

private extension View {
    func linkPanel() -> some View {
        padding(16)
            .background(.cyan.opacity(0.035), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.cyan.opacity(0.16)))
    }
}
