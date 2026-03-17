/// LIFX protocol constants for bulb provisioning.
/// Values verified against tserong/lifx-hacks reference implementation.

import Foundation

enum LIFXConstants {
    static let port: UInt16 = 56700
    static let bulbAPIP: String = "172.16.0.1"
    static let bulbAPPrefix: String = "LIFX"

    // LIFX header
    static let headerSize: Int = 36
    static let protocol_: UInt16 = 1024
    static let addressable: UInt16 = 1 << 12
    static let tagged: UInt16 = 1 << 13

    // Message types
    static let msgSetAccessPoint: UInt16 = 305

    // SetAccessPoint payload sizes
    static let interfaceSize: Int = 1
    static let ssidSize: Int = 32
    static let passwordSize: Int = 64
    static let securitySize: Int = 1

    // Interface: 0x02 = STA (station) per reference implementation
    static let interfaceSTA: UInt8 = 0x02
}

/// WiFi security types for SetAccessPoint.
/// Values from tserong/lifx-hacks (NOT the zombience gist, which had wrong values).
enum WiFiSecurity: UInt8 {
    case open        = 0x01
    case wepPSK      = 0x02
    case wpaTKIP     = 0x03
    case wpaAES      = 0x04
    case wpa2AES     = 0x05  // most common
    case wpa2TKIP    = 0x06
    case wpa2Mixed   = 0x07
}
