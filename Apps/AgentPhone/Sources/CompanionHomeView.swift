import AgentLink
import SwiftUI
import VisionKit

struct CompanionHomeView: View {
    @State private var pairingCode = ""
    @State private var command = ""
    @State private var showingScanner = false
    @StateObject private var link = AgentLinkClient(name: UIDevice.current.name)

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
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .foregroundStyle(.cyan)
        .onAppear(perform: link.start)
        .onDisappear(perform: link.stop)
        .fullScreenCover(isPresented: $showingScanner) {
            PairingScannerView { code in
                pairingCode = code
                showingScanner = false
                link.pair(code: code)
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("AGENT // MOBILE LINK")
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                Text("TLS 1.3 // KEYCHAIN TRUST")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.cyan.opacity(0.55))
            }
            Spacer()
            Circle()
                .fill(link.state.color)
                .frame(width: 8, height: 8)
                .shadow(color: link.state.color, radius: 6)
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
                Text(link.state.label)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
            }
        }
        .frame(height: 190)
    }

    private var pairingPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PAIRING CODE")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
            Button {
                showingScanner = true
            } label: {
                Label("MAC QR 스캔", systemImage: "qrcode.viewfinder")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(LinkButtonStyle())
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
                link.pair(code: pairingCode)
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
                    link.sendCommand(command.trimmingCharacters(in: .whitespacesAndNewlines))
                    command = ""
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 26))
                }
                .buttonStyle(.plain)
                .disabled(!link.state.isConnected || command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(14)
            .background(.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.cyan.opacity(0.2)))
        }
        .linkPanel()
    }
}

private struct PairingScannerView: View {
    let onCode: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                AgentQRCodeScanner(onCode: onCode)
                    .ignoresSafeArea()
            } else {
                ContentUnavailableView(
                    "QR 스캐너를 사용할 수 없음",
                    systemImage: "camera.fill",
                    description: Text("카메라를 사용할 수 있는 실제 iPhone에서 다시 시도해 주세요.")
                )
            }

            VStack {
                HStack {
                    Button(action: dismiss.callAsFunction) {
                        Image(systemName: "xmark")
                            .font(.headline)
                            .padding(12)
                            .background(.black.opacity(0.65), in: Circle())
                    }
                    Spacer()
                }
                Spacer()
                Text("Mac Agent에 표시된 QR 코드를 비춰주세요")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(.black.opacity(0.72), in: Capsule())
            }
            .foregroundStyle(.white)
            .padding(20)
        }
    }
}

private struct AgentQRCodeScanner: UIViewControllerRepresentable {
    let onCode: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCode: onCode)
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: true,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        controller.delegate = context.coordinator
        try? controller.startScanning()
        return controller
    }

    func updateUIViewController(_ controller: DataScannerViewController, context: Context) {}

    static func dismantleUIViewController(_ controller: DataScannerViewController, coordinator: Coordinator) {
        controller.stopScanning()
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private let onCode: (String) -> Void
        private var completed = false

        init(onCode: @escaping (String) -> Void) {
            self.onCode = onCode
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            guard !completed else { return }
            for item in addedItems {
                guard case let .barcode(barcode) = item,
                      let payload = barcode.payloadStringValue,
                      let code = AgentLinkPairingPayload.decode(payload) else {
                    continue
                }
                completed = true
                dataScanner.stopScanning()
                onCode(code)
                return
            }
        }
    }
}

private extension AgentLinkConnectionState {
    var label: String {
        switch self {
        case .idle: "LINK OFFLINE"
        case .searching: "SEARCHING FOR MAC"
        case .advertising: "ADVERTISING"
        case .connecting: "CONNECTING"
        case .pairing: "AWAITING PAIRING CODE"
        case .connected: "LOCAL LINK READY"
        case .failed: "CONNECTION FAILED"
        }
    }

    var color: Color {
        switch self {
        case .idle, .searching, .connecting, .pairing, .advertising: .orange
        case .connected: .cyan
        case .failed: .red
        }
    }

    var isConnected: Bool {
        if case .connected = self { true } else { false }
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
