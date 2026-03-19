// Copyright (c) 2026 Perry Kivolowitz — MIT License (see LICENSE)
/// TLS connection to LIFX bulb AP at 172.16.0.1:56700.
/// Sends SetAccessPoint (message type 305) with new WiFi credentials.
///
/// Be kind to the bulb: send once, wait patiently, close cleanly.

import Foundation
import Network

enum BulbProvisionerError: LocalizedError {
    case connectionFailed(String)
    case sendFailed(String)
    case timeout

    var errorDescription: String? {
        switch self {
        case .connectionFailed(let reason):
            return "Could not connect to bulb: \(reason)"
        case .sendFailed(let reason):
            return "Failed to send credentials: \(reason)"
        case .timeout:
            return "Bulb did not respond in time"
        }
    }
}

enum BulbProvisioner {

    /// Connects to the bulb's AP over TLS, sends SetAccessPoint, and closes.
    /// The bulb will reboot and attempt to join the target network.
    static func provision(
        ssid: String,
        password: String,
        security: WiFiSecurity = .wpa2AES,
        host: String = LIFXConstants.bulbAPIP,
        port: UInt16 = LIFXConstants.port,
        timeout: TimeInterval = 15.0
    ) async throws {
        let packet = LIFXPacket.buildSetAccessPoint(
            ssid: ssid,
            password: password,
            security: security
        )

        let connection = createTLSConnection(host: host, port: port)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            var resumed = false
            let lock = NSLock()

            func resumeOnce(with result: Result<Void, Error>) {
                lock.lock()
                defer { lock.unlock() }
                guard !resumed else { return }
                resumed = true
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            // Timeout
            let deadline = DispatchTime.now() + timeout
            DispatchQueue.global().asyncAfter(deadline: deadline) {
                connection.cancel()
                resumeOnce(with: .failure(BulbProvisionerError.timeout))
            }

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    // Connected — send the packet once
                    connection.send(content: packet, completion: .contentProcessed { error in
                        if let error {
                            connection.cancel()
                            resumeOnce(with: .failure(
                                BulbProvisionerError.sendFailed(error.localizedDescription)
                            ))
                        } else {
                            // Sent successfully — give the bulb a moment, then close cleanly
                            DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) {
                                connection.cancel()
                                resumeOnce(with: .success(()))
                            }
                        }
                    })

                case .failed(let error):
                    connection.cancel()
                    resumeOnce(with: .failure(
                        BulbProvisionerError.connectionFailed(error.localizedDescription)
                    ))

                case .cancelled:
                    resumeOnce(with: .failure(
                        BulbProvisionerError.connectionFailed("Connection cancelled")
                    ))

                default:
                    break
                }
            }

            connection.start(queue: .global())
        }
    }

    // MARK: - Private

    /// Creates a TLS connection that accepts the bulb's self-signed certificate.
    private static func createTLSConnection(host: String, port: UInt16) -> NWConnection {
        let tlsOptions = NWProtocolTLS.Options()

        // The bulb uses a self-signed cert — skip verification
        sec_protocol_options_set_verify_block(
            tlsOptions.securityProtocolOptions,
            { _, _, completionHandler in
                completionHandler(true)
            },
            .global()
        )

        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.connectionTimeout = 10

        let params = NWParameters(tls: tlsOptions, tcp: tcpOptions)

        return NWConnection(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(rawValue: port)!,
            using: params
        )
    }
}
