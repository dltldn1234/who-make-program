import Foundation
import Testing
@testable import AgentLink

@Suite("Agent link stream framing")
struct AgentLinkFrameCodecTests {
    @Test("A fragmented frame is emitted only after it is complete")
    func fragmentedFrame() throws {
        let payload = Data("hello".utf8)
        let frame = try AgentLinkFrameEncoder().encode(payload)
        var decoder = AgentLinkFrameDecoder()

        #expect(try decoder.append(frame.prefix(3)).isEmpty)
        #expect(try decoder.append(frame.dropFirst(3)) == [payload])
    }

    @Test("Multiple frames are decoded from one network read")
    func multipleFrames() throws {
        let encoder = AgentLinkFrameEncoder()
        let first = Data("first".utf8)
        let second = Data("second".utf8)
        var combined = try encoder.encode(first)
        combined.append(try encoder.encode(second))
        var decoder = AgentLinkFrameDecoder()

        #expect(try decoder.append(combined) == [first, second])
    }

    @Test("Oversized frames are rejected before buffering their body")
    func oversizedFrame() {
        let invalidLength = UInt32(AgentLinkCodec.maximumPayloadBytes + 1)
        let header = Data([
            UInt8((invalidLength >> 24) & 0xff),
            UInt8((invalidLength >> 16) & 0xff),
            UInt8((invalidLength >> 8) & 0xff),
            UInt8(invalidLength & 0xff),
        ])
        var decoder = AgentLinkFrameDecoder()

        #expect(throws: AgentLinkFrameError.oversizedPayload) {
            try decoder.append(header)
        }
    }
}
