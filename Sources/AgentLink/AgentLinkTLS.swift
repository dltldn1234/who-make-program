import Foundation
import Network
import Security

enum AgentLinkTLS {
    static let pairingIdentity = Data("agent-link-pairing".utf8)

    static func parameters(credentials: [(identity: Data, secret: Data)]) -> NWParameters {
        let tls = NWProtocolTLS.Options()
        let options = tls.securityProtocolOptions
        sec_protocol_options_set_min_tls_protocol_version(options, .TLSv13)
        sec_protocol_options_set_max_tls_protocol_version(options, .TLSv13)

        for credential in credentials {
            sec_protocol_options_add_pre_shared_key(
                options,
                dispatchData(credential.secret) as dispatch_data_t,
                dispatchData(credential.identity) as dispatch_data_t
            )
        }

        let parameters = NWParameters(tls: tls, tcp: NWProtocolTCP.Options())
        parameters.includePeerToPeer = true
        return parameters
    }

    static func identity(for credential: AgentLinkCredential) -> Data {
        Data(credential.id.uuidString.lowercased().utf8)
    }

    private static func dispatchData(_ data: Data) -> DispatchData {
        data.withUnsafeBytes { DispatchData(bytes: $0) }
    }
}
