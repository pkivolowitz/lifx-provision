/// LIFX protocol packet construction.
/// Builds the 36-byte header and SetAccessPoint payload.
/// Verified against tserong/lifx-hacks reference implementation.
///
/// Header layout (36 bytes, little-endian throughout):
///   Frame (8 bytes):
///     uint16  size            — total packet length
///     uint16  origin:2 | tagged:1 | addressable:1 | protocol:12
///     uint32  source          — zero for onboarding
///   Frame Address (16 bytes):
///     uint8[8]  target        — all zeros (broadcast)
///     uint8[6]  reserved
///     uint8     res_required:1 | ack_required:1 | reserved:6
///     uint8     sequence
///   Protocol Header (12 bytes):
///     uint64  reserved
///     uint16  type            — 305 = SetAccessPoint
///     uint16  reserved

import Foundation

enum LIFXPacket {

    /// Builds a complete SetAccessPoint packet.
    /// Reference: header is 0x86,0x00,0x00,0x34,...,0x31,0x01,0x00,0x00,0x02
    static func buildSetAccessPoint(
        ssid: String,
        password: String,
        security: WiFiSecurity = .wpa2AES,
        iface: UInt8 = LIFXConstants.interfaceSTA
    ) -> Data {
        let payloadSize = LIFXConstants.interfaceSize
            + LIFXConstants.ssidSize
            + LIFXConstants.passwordSize
            + LIFXConstants.securitySize
        let totalSize = LIFXConstants.headerSize + payloadSize  // 36 + 98 = 134

        var packet = Data(count: totalSize)

        // --- Frame (8 bytes) ---

        // size (uint16 LE) = 134 = 0x0086
        packet[0] = UInt8(totalSize & 0xFF)
        packet[1] = UInt8((totalSize >> 8) & 0xFF)

        // protocol(12)=1024 | addressable(1)=1 | tagged(1)=1 | origin(2)=0
        // = 0x0400 | 0x1000 | 0x2000 = 0x3400
        let frameField: UInt16 = LIFXConstants.protocol_
            | LIFXConstants.addressable
            | LIFXConstants.tagged
        packet[2] = UInt8(frameField & 0xFF)
        packet[3] = UInt8((frameField >> 8) & 0xFF)

        // source (uint32 LE) = 0 per reference
        // (already zeroed)

        // --- Frame Address (16 bytes at offset 8) ---
        // target[8] = all zeros (broadcast to connected bulb)
        // reserved[6] = zeros
        // res_required | ack_required = 0
        // sequence = 0
        // (already zeroed)

        // --- Protocol Header (12 bytes at offset 24) ---
        // reserved[8] = zeros (already zeroed)

        // type (uint16 LE) at offset 32: 305 = 0x0131
        packet[32] = UInt8(LIFXConstants.msgSetAccessPoint & 0xFF)
        packet[33] = UInt8((LIFXConstants.msgSetAccessPoint >> 8) & 0xFF)

        // reserved[2] at offset 34 (already zeroed)

        // --- Payload (98 bytes at offset 36) ---

        var offset = LIFXConstants.headerSize

        // interface (1 byte) = 0x02 per reference
        packet[offset] = iface
        offset += LIFXConstants.interfaceSize

        // SSID (32 bytes, UTF-8, null-padded)
        let ssidBytes = Array(ssid.utf8.prefix(LIFXConstants.ssidSize))
        for (i, byte) in ssidBytes.enumerated() {
            packet[offset + i] = byte
        }
        offset += LIFXConstants.ssidSize

        // password (64 bytes, UTF-8, null-padded)
        let passBytes = Array(password.utf8.prefix(LIFXConstants.passwordSize))
        for (i, byte) in passBytes.enumerated() {
            packet[offset + i] = byte
        }
        offset += LIFXConstants.passwordSize

        // security type (1 byte)
        packet[offset] = security.rawValue

        return packet
    }
}
