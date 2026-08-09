import Foundation

public enum AgentLinkFrameError: Error, Equatable, Sendable {
    case emptyPayload
    case oversizedPayload
}

public struct AgentLinkFrameEncoder: Sendable {
    public init() {}

    public func encode(_ payload: Data) throws -> Data {
        guard !payload.isEmpty else {
            throw AgentLinkFrameError.emptyPayload
        }
        guard payload.count <= AgentLinkCodec.maximumPayloadBytes else {
            throw AgentLinkFrameError.oversizedPayload
        }

        var length = UInt32(payload.count).bigEndian
        var frame = Data(bytes: &length, count: MemoryLayout<UInt32>.size)
        frame.append(payload)
        return frame
    }
}

public struct AgentLinkFrameDecoder: Sendable {
    private static let headerSize = MemoryLayout<UInt32>.size
    private var buffer = Data()

    public init() {}

    public mutating func append(_ data: Data) throws -> [Data] {
        buffer.append(data)
        var payloads: [Data] = []

        while buffer.count >= Self.headerSize {
            let headerEnd = buffer.index(buffer.startIndex, offsetBy: Self.headerSize)
            let length = buffer[buffer.startIndex..<headerEnd].reduce(UInt32.zero) {
                ($0 << 8) | UInt32($1)
            }
            guard length > 0 else {
                throw AgentLinkFrameError.emptyPayload
            }
            guard length <= AgentLinkCodec.maximumPayloadBytes else {
                throw AgentLinkFrameError.oversizedPayload
            }

            let frameSize = Self.headerSize + Int(length)
            guard buffer.count >= frameSize else {
                break
            }

            let frameEnd = buffer.index(buffer.startIndex, offsetBy: frameSize)
            payloads.append(Data(buffer[headerEnd..<frameEnd]))
            buffer.removeSubrange(buffer.startIndex..<frameEnd)
        }

        return payloads
    }
}
