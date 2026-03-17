/// Connects to a named SSID via NEHotspotConfiguration and
/// reconnects to the home network after provisioning.

import Foundation
import NetworkExtension
import CoreLocation
import SystemConfiguration.CaptiveNetwork

enum WiFiConnectorError: LocalizedError {
    case connectionFailed(String)
    case verificationFailed(expected: String, actual: String?)
    case locationDenied
    case timeout

    var errorDescription: String? {
        switch self {
        case .connectionFailed(let reason):
            return "Failed to connect: \(reason)"
        case .verificationFailed(let expected, let actual):
            return "Expected SSID \"\(expected)\" but got \"\(actual ?? "none")\""
        case .locationDenied:
            return "Location permission required to verify WiFi network"
        case .timeout:
            return "Operation timed out"
        }
    }
}

/// Manages WiFi switching for LIFX bulb provisioning.
/// Uses NEHotspotConfiguration to join/leave networks and
/// NEHotspotNetwork to verify the current SSID.
final class WiFiConnector: NSObject, CLLocationManagerDelegate {

    private let locationManager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<Void, Never>?

    override init() {
        super.init()
        locationManager.delegate = self
    }

    /// Ensures location permission is granted (required to read current SSID).
    func ensureLocationPermission() async {
        let status = locationManager.authorizationStatus
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            return
        }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            locationContinuation = continuation
            locationManager.requestWhenInUseAuthorization()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        if status != .notDetermined {
            locationContinuation?.resume()
            locationContinuation = nil
        }
    }

    /// Returns the SSID of the currently connected WiFi network, or nil.
    func currentSSID() async -> String? {
        await withCheckedContinuation { continuation in
            NEHotspotNetwork.fetchCurrent { network in
                continuation.resume(returning: network?.ssid)
            }
        }
    }

    /// Connects to an open (no password) SSID.
    /// The system will show a "Join network?" prompt.
    func connect(to ssid: String) async throws {
        let config = NEHotspotConfiguration(ssid: ssid)
        config.joinOnce = true

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            NEHotspotConfigurationManager.shared.apply(config) { error in
                if let error {
                    // "already associated" is not a real error
                    if (error as NSError).domain == NEHotspotConfigurationErrorDomain &&
                       (error as NSError).code == NEHotspotConfigurationError.alreadyAssociated.rawValue {
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: WiFiConnectorError.connectionFailed(error.localizedDescription))
                    }
                } else {
                    continuation.resume()
                }
            }
        }
    }

    /// Disconnects from a previously joined SSID.
    /// The phone will auto-rejoin its preferred network.
    func disconnect(from ssid: String) {
        NEHotspotConfigurationManager.shared.removeConfiguration(forSSID: ssid)
    }

    /// Verifies that the device is currently connected to the expected SSID.
    /// Retries a few times to allow for connection settling.
    func verifyConnected(to expectedSSID: String, retries: Int = 5, delay: TimeInterval = 2.0) async throws {
        for _ in 0..<retries {
            if let current = await currentSSID(), current == expectedSSID {
                return
            }
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        let actual = await currentSSID()
        throw WiFiConnectorError.verificationFailed(expected: expectedSSID, actual: actual)
    }
}
