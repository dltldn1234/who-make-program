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
    private var pairingCode = ""
    private var listener: NWListener?
    private var channel: AgentLinkChannel?
    private var paired = false

    public init(name: String) {
        identity = AgentDeviceIdentity(id: UUID(), name: name, kind: .mac)
    }

    public func start() {
        stop()
        pairingCode = String(format: "%06d", Int.random(in: 0...999_999))

        do {
            let parameters = NWParameters.tcp
            parameters.acceptLocalOnly = true
            parameters.includePeerToPeer = true
            let listener = try NWListener(using: parameters)
            listener.service = NWListener.Service(name: identity.name, type: AgentLinkService.type)
            listener.stateUpdateHandler = { [weak self] listenerState in
                Task { @MainActor [weak self] in
                    self?.handleListenerState(listenerState)
                }
            }
            listener.newConnectionHandler = { [weak self] connection in
                Task { @MainActor [weak self] in
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
            paired = true
            state = .connected(peerName: device.name)
            channel?.send(.pairingAccepted(device: identity))
        case .pairingRequest:
            channel?.send(.error(code: "invalid_pairing_code", message: "페어링 코드가 일치하지 않습니다."))
            channel?.cancel()
        case let .command(text) where paired:
            lastCommand = text
            onCommand?(text)
        case .heartbeat where paired:
            channel?.send(.heartbeat)
        default:
            channel?.send(.error(code: "pairing_required", message: "명령 전송 전에 페어링이 필요합니다."))
        }
    }

    private func handleListenerState(_ listenerState: NWListener.State) {
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
    private var pairingCode = ""
    private var browser: NWBrowser?
    private var channel: AgentLinkChannel?

    public init(name: String) {
        identity = AgentDeviceIdentity(id: UUID(), name: name, kind: .iPhone)
    }

    public func start() {
        stop()
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
                self?.connect(to: endpoint)
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
        if channel == nil {
            start()
        } else {
            state = .pairing
            channel?.send(.pairingRequest(device: identity, code: code))
        }
    }

    public func sendCommand(_ text: String) {
        guard case .connected = state else { return }
        channel?.send(.command(text: text))
    }

    public func stop() {
        channel?.cancel()
        channel = nil
        browser?.cancel()
        browser = nil
        state = .idle
    }

    private func connect(to endpoint: NWEndpoint) {
        guard channel == nil else { return }
        state = .connecting
        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true
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
        case let .error(_, message):
            state = .failed(message: message)
        default:
            break
        }
    }

    private func handleConnectionState(_ connectionState: NWConnection.State) {
        switch connectionState {
        case .ready:
            guard pairingCode.count == 6 else {
                state = .pairing
                return
            }
            state = .pairing
            channel?.send(.pairingRequest(device: identity, code: pairingCode))
        case .failed(let error):
            channel = nil
            state = .failed(message: error.localizedDescription)
        case .cancelled:
            channel = nil
            if browser != nil {
                state = .searching
            }
        default:
            break
        }
    }
}
