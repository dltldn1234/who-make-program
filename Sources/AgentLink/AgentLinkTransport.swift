import Combine
import Foundation
import Network

public enum AgentLinkConnectionState: Equatable, Sendable {
    case idle
    case searching
    case advertising(code: String)
    case connecting
    case pairing
    case connected(peerName: String)
    case failed(message: String)
}

public enum AgentLinkService {
    public static let type = "_agent-link._tcp"
}

final class AgentLinkChannel: @unchecked Sendable {
    private let connection: NWConnection
    private let queue: DispatchQueue
    private let codec = AgentLinkCodec()
    private let frameEncoder = AgentLinkFrameEncoder()
    private var frameDecoder = AgentLinkFrameDecoder()
    private let onMessage: @Sendable (AgentLinkEnvelope) -> Void
    private let onState: @Sendable (NWConnection.State) -> Void

    init(
        connection: NWConnection,
        label: String,
        onMessage: @escaping @Sendable (AgentLinkEnvelope) -> Void,
        onState: @escaping @Sendable (NWConnection.State) -> Void
    ) {
        self.connection = connection
        queue = DispatchQueue(label: label)
        self.onMessage = onMessage
        self.onState = onState
    }

    func start() {
        connection.stateUpdateHandler = onState
        connection.start(queue: queue)
        receive()
    }

    func send(_ message: AgentLinkMessage) {
        queue.async { [self] in
            do {
                let payload = try codec.encode(AgentLinkEnvelope(message: message))
                let frame = try frameEncoder.encode(payload)
                connection.send(content: frame, completion: .contentProcessed { _ in })
            } catch {
                connection.cancel()
            }
        }
    }

    func cancel() {
        connection.cancel()
    }

    private func receive() {
        connection.receive(
            minimumIncompleteLength: 1,
            maximumLength: AgentLinkCodec.maximumPayloadBytes + MemoryLayout<UInt32>.size
        ) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data, !data.isEmpty {
                do {
                    for payload in try frameDecoder.append(data) {
                        onMessage(try codec.decode(payload))
                    }
                } catch {
                    connection.cancel()
                    return
                }
            }
            if error == nil, !isComplete {
                receive()
            }
        }
    }
}

@MainActor
public final class AgentLinkServer: ObservableObject {
    @Published public private(set) var state: AgentLinkConnectionState = .idle
    @Published public private(set) var lastCommand = ""

    public var onCommand: ((String) -> Void)?

    private let identity: AgentDeviceIdentity
    private let trustStore = AgentLinkTrustStore()
    private var pairingCode = ""
    private var trustedCredential: AgentLinkCredential?
    private var listener: NWListener?
    private var channel: AgentLinkChannel?
    private var paired = false
    private var listenerGeneration = UUID()
    private var trustRefreshTask: Task<Void, Never>?

    public init(name: String) {
        identity = AgentDeviceIdentity(id: UUID(), name: name, kind: .mac)
    }

    public func start() {
        stop()
        listenerGeneration = UUID()
        let generation = listenerGeneration
        pairingCode = String(format: "%06d", Int.random(in: 0...999_999))

        do {
            trustedCredential = try trustStore.load()
            var tlsCredentials = [(
                identity: AgentLinkTLS.pairingIdentity,
                secret: try AgentLinkPairingKey.derive(from: pairingCode)
            )]
            if let trustedCredential {
                tlsCredentials.append((
                    identity: AgentLinkTLS.identity(for: trustedCredential),
                    secret: trustedCredential.secret
                ))
            }
            let parameters = AgentLinkTLS.parameters(credentials: tlsCredentials)
            parameters.acceptLocalOnly = true
            let listener = try NWListener(using: parameters)
            listener.service = NWListener.Service(name: identity.name, type: AgentLinkService.type)
            listener.stateUpdateHandler = { [weak self] listenerState in
                Task { @MainActor [weak self] in
                    self?.handleListenerState(listenerState, generation: generation)
                }
            }
            listener.newConnectionHandler = { [weak self] connection in
                Task { @MainActor [weak self] in
                    guard self?.listenerGeneration == generation else { return }
                    self?.accept(connection)
                }
            }
            self.listener = listener
            listener.start(queue: DispatchQueue(label: "agent.link.listener"))
            state = .advertising(code: pairingCode)
        } catch {
            state = .failed(message: error.localizedDescription)
        }
    }

    public func stop() {
        trustRefreshTask?.cancel()
        trustRefreshTask = nil
        channel?.cancel()
        channel = nil
        listener?.cancel()
        listener = nil
        paired = false
        state = .idle
    }

    private func accept(_ connection: NWConnection) {
        channel?.cancel()
        paired = false
        state = .pairing
        let channel = AgentLinkChannel(
            connection: connection,
            label: "agent.link.server.connection",
            onMessage: { [weak self] envelope in
                Task { @MainActor [weak self] in
                    self?.handle(envelope)
                }
            },
            onState: { [weak self] connectionState in
                Task { @MainActor [weak self] in
                    self?.handleConnectionState(connectionState)
                }
            }
        )
        self.channel = channel
        channel.start()
    }

    private func handle(_ envelope: AgentLinkEnvelope) {
        switch envelope.message {
        case let .pairingRequest(device, code) where code == pairingCode:
            establishTrust(with: device)
        case .pairingRequest:
            channel?.send(.error(code: "invalid_pairing_code", message: "페어링 코드가 일치하지 않습니다."))
            channel?.cancel()
        case let .command(text) where paired:
            lastCommand = text
            onCommand?(text)
        case .heartbeat where paired:
            channel?.send(.heartbeat)
        case let .trustedSession(device)
            where trustedCredential?.peer.id == device.id:
            paired = true
            state = .connected(peerName: device.name)
            channel?.send(.pairingAccepted(device: identity))
        default:
            channel?.send(.error(code: "pairing_required", message: "명령 전송 전에 페어링이 필요합니다."))
        }
    }

    private func establishTrust(with device: AgentDeviceIdentity) {
        do {
            let serverCredential = try AgentLinkCredential.generate(for: device)
            try trustStore.save(serverCredential)
            trustedCredential = serverCredential
            paired = true
            state = .connected(peerName: device.name)
            let clientCredential = AgentLinkCredential(
                id: serverCredential.id,
                peer: identity,
                secret: serverCredential.secret
            )
            channel?.send(.trustEstablished(device: identity, credential: clientCredential))
            scheduleListenerRefresh()
        } catch {
            state = .failed(message: "기기 신뢰 정보를 저장하지 못했습니다.")
            channel?.cancel()
        }
    }

    private func scheduleListenerRefresh() {
        trustRefreshTask?.cancel()
        trustRefreshTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(750))
            guard !Task.isCancelled else { return }
            self?.start()
        }
    }

    private func handleListenerState(
        _ listenerState: NWListener.State,
        generation: UUID
    ) {
        guard generation == listenerGeneration else { return }
        switch listenerState {
        case .failed(let error):
            state = .failed(message: error.localizedDescription)
        case .cancelled where listener != nil:
            state = .idle
        default:
            break
        }
    }

    private func handleConnectionState(_ connectionState: NWConnection.State) {
        switch connectionState {
        case .failed(let error):
            paired = false
            state = .failed(message: error.localizedDescription)
        case .cancelled:
            paired = false
            state = listener == nil ? .idle : .advertising(code: pairingCode)
        default:
            break
        }
    }
}

@MainActor
public final class AgentLinkClient: ObservableObject {
    @Published public private(set) var state: AgentLinkConnectionState = .idle

    private let identity: AgentDeviceIdentity
    private let trustStore = AgentLinkTrustStore()
    private var pairingCode = ""
    private var trustedCredential: AgentLinkCredential?
    private var discoveredEndpoint: NWEndpoint?
    private var browser: NWBrowser?
    private var channel: AgentLinkChannel?
    private var retryTask: Task<Void, Never>?
    private var retryAttempt = 0

    public init(name: String) {
        identity = AgentDeviceIdentity(id: UUID(), name: name, kind: .iPhone)
    }

    public func start() {
        stop()
        trustedCredential = try? trustStore.load()
        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true
        let browser = NWBrowser(for: .bonjour(type: AgentLinkService.type, domain: nil), using: parameters)
        browser.stateUpdateHandler = { [weak self] browserState in
            Task { @MainActor [weak self] in
                if case let .failed(error) = browserState {
                    self?.state = .failed(message: error.localizedDescription)
                }
            }
        }
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            guard let endpoint = results.first?.endpoint else { return }
            Task { @MainActor [weak self] in
                self?.discover(endpoint)
            }
        }
        self.browser = browser
        state = .searching
        browser.start(queue: DispatchQueue(label: "agent.link.browser"))
    }

    public func pair(code: String) {
        pairingCode = code
        guard code.count == 6, code.allSatisfy(\.isNumber) else {
            state = .failed(message: "6자리 페어링 코드를 입력하세요.")
            return
        }
        guard let discoveredEndpoint else {
            start()
            return
        }
        connectForPairing(to: discoveredEndpoint, code: code)
    }

    public func sendCommand(_ text: String) {
        guard case .connected = state else { return }
        channel?.send(.command(text: text))
    }

    public func stop() {
        retryTask?.cancel()
        retryTask = nil
        retryAttempt = 0
        channel?.cancel()
        channel = nil
        browser?.cancel()
        browser = nil
        discoveredEndpoint = nil
        state = .idle
    }

    private func discover(_ endpoint: NWEndpoint) {
        discoveredEndpoint = endpoint
        retryTask?.cancel()
        if let trustedCredential {
            connect(to: endpoint, credential: trustedCredential, pairingCode: nil)
        } else {
            state = .pairing
        }
    }

    private func connectForPairing(to endpoint: NWEndpoint, code: String) {
        do {
            let credential = AgentLinkCredential(
                peer: AgentDeviceIdentity(id: UUID(), name: "Pairing", kind: .mac),
                secret: try AgentLinkPairingKey.derive(from: code)
            )
            connect(to: endpoint, credential: credential, pairingCode: code)
        } catch {
            state = .failed(message: "유효한 페어링 코드를 입력하세요.")
        }
    }

    private func connect(
        to endpoint: NWEndpoint,
        credential: AgentLinkCredential,
        pairingCode: String?
    ) {
        guard channel == nil else { return }
        state = .connecting
        let tlsIdentity = pairingCode == nil
            ? AgentLinkTLS.identity(for: credential)
            : AgentLinkTLS.pairingIdentity
        let parameters = AgentLinkTLS.parameters(credentials: [(
            identity: tlsIdentity,
            secret: credential.secret
        )])
        let channel = AgentLinkChannel(
            connection: NWConnection(to: endpoint, using: parameters),
            label: "agent.link.client.connection",
            onMessage: { [weak self] envelope in
                Task { @MainActor [weak self] in
                    self?.handle(envelope)
                }
            },
            onState: { [weak self] connectionState in
                Task { @MainActor [weak self] in
                    self?.handleConnectionState(connectionState)
                }
            }
        )
        self.channel = channel
        channel.start()
    }

    private func handle(_ envelope: AgentLinkEnvelope) {
        switch envelope.message {
        case let .pairingAccepted(device):
            state = .connected(peerName: device.name)
        case let .trustEstablished(device, credential):
            do {
                try trustStore.save(credential)
                trustedCredential = credential
                pairingCode = ""
                state = .connected(peerName: device.name)
            } catch {
                state = .failed(message: "기기 신뢰 정보를 저장하지 못했습니다.")
                channel?.cancel()
            }
        case let .error(_, message):
            state = .failed(message: message)
        default:
            break
        }
    }

    private func handleConnectionState(_ connectionState: NWConnection.State) {
        switch connectionState {
        case .ready:
            retryAttempt = 0
            if trustedCredential != nil, pairingCode.isEmpty {
                channel?.send(.trustedSession(device: identity))
            } else {
                state = .pairing
                channel?.send(.pairingRequest(device: identity, code: pairingCode))
            }
        case .failed(let error):
            channel = nil
            state = .failed(message: error.localizedDescription)
            scheduleTrustedReconnect()
        case .cancelled:
            channel = nil
            if browser != nil {
                state = .searching
                scheduleTrustedReconnect()
            }
        default:
            break
        }
    }

    private func scheduleTrustedReconnect() {
        guard pairingCode.isEmpty,
              let trustedCredential,
              let discoveredEndpoint,
              retryTask == nil else { return }

        let delay = min(pow(2, Double(retryAttempt)), 8)
        retryAttempt += 1
        retryTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, let self else { return }
            retryTask = nil
            connect(to: discoveredEndpoint, credential: trustedCredential, pairingCode: nil)
        }
    }
}
