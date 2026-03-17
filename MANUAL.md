# LIFX Bulk WiFi Provisioning — Technical Manual

## Overview

This tool sends WiFi credentials to LIFX smart bulbs that have been hardware-reset into AP mode. It replaces the manual per-bulb provisioning process in the LIFX app.

Two implementations exist:
- **macOS CLI**: a Swift command-line tool using `networksetup` for WiFi switching
- **iOS app**: a SwiftUI app using screenshot OCR for bulb discovery and `NEHotspotConfiguration` for WiFi switching

Both use the same LIFX provisioning protocol over TLS.

## LIFX Provisioning Protocol

### Bulb AP Mode

After a hardware reset (power cycle 5 times), a LIFX bulb:
- Broadcasts an open WiFi network named "LIFX \<model\> \<3 hex octets\>"
- Runs a TLS server at 172.16.0.1:56700
- Uses a self-signed certificate
- Accepts `SetAccessPoint` messages (type 305)
- Reboots and joins the specified network upon receiving valid credentials

### SetAccessPoint Packet (134 bytes)

All values are little-endian.

#### Header (36 bytes)

| Offset | Size | Value | Description |
|--------|------|-------|-------------|
| 0 | 2 | 0x0086 | Total packet size (134) |
| 2 | 2 | 0x3400 | Protocol 1024, addressable=1, tagged=1, origin=0 |
| 4 | 4 | 0x00000000 | Source (zero) |
| 8 | 8 | 0x0000000000000000 | Target (zero = broadcast) |
| 16 | 6 | 0x000000000000 | Reserved |
| 22 | 1 | 0x00 | Response flags (none) |
| 23 | 1 | 0x00 | Sequence number |
| 24 | 8 | 0x0000000000000000 | Reserved |
| 32 | 2 | 0x3101 | Message type 305 (SetAccessPoint) |
| 34 | 2 | 0x0000 | Reserved |

#### Payload (98 bytes)

| Offset | Size | Description |
|--------|------|-------------|
| 36 | 1 | Interface: 0x02 (station) |
| 37 | 32 | SSID (UTF-8, null-padded) |
| 69 | 64 | Password (UTF-8, null-padded) |
| 133 | 1 | Security type |

#### Security Types

| Value | Type |
|-------|------|
| 0x01 | Open |
| 0x02 | WEP PSK |
| 0x03 | WPA TKIP PSK |
| 0x04 | WPA AES PSK |
| 0x05 | WPA2 AES PSK (most common) |
| 0x06 | WPA2 TKIP PSK |
| 0x07 | WPA2 Mixed PSK |

These values were verified against the [tserong/lifx-hacks](https://github.com/tserong/lifx-hacks) reference implementation. Note: the widely-cited [zombience gist](https://gist.github.com/zombience/981d5920160fcca98e829082aa2d426f) uses a different (incorrect) numbering scheme.

### Connection Sequence

1. Connect to the bulb's open WiFi AP
2. Wait for DHCP (2-4 seconds)
3. Open TLS connection to 172.16.0.1:56700 (accept self-signed cert)
4. Send the 134-byte SetAccessPoint packet
5. Wait 2 seconds for the bulb to process
6. Close the connection
7. Disconnect from the bulb's AP

The bulb reboots and attempts to join the specified network. There is no acknowledgment message.

## macOS CLI Architecture

Single Swift file (`cli/lifx-provision.swift`). No external dependencies.

### WiFi Switching

Uses `networksetup` via `Process`:
- `networksetup -getairportnetwork en0` — read current SSID
- `networksetup -setairportnetwork en0 "SSID"` — join an open network
- `networksetup -setairportnetwork en0 "SSID" "password"` — join a secured network

Does not use CoreWLAN. Apple requires Location Services authorization for CoreWLAN, which is effectively unavailable to CLI tools on modern macOS. Apple redacts all WiFi identifiers (SSIDs, BSSIDs, MAC addresses) from unauthorized processes.

### TLS

Uses `NWConnection` (Network framework) with `NWProtocolTLS.Options`. Certificate verification is disabled via `sec_protocol_options_set_verify_block` to accept the bulb's self-signed certificate.

### Build

```
swiftc -O -framework Network -framework Security cli/lifx-provision.swift -o lifx-provision
```

Requires only the Swift compiler, included with Xcode Command Line Tools (`xcode-select --install`). No Apple Developer account.

## iOS App Architecture

### The WiFi Scanning Problem

Apple does not provide any public API for scanning WiFi networks on iOS:
- `CNCopyCurrentNetworkInfo` reads the current SSID but cannot scan
- `NEHotspotHelper` requires a carrier-level entitlement Apple does not grant to developers
- `NEHotspotConfiguration` can connect to a known SSID but cannot discover SSIDs

The LIFX app handles this by encoding bulb AP names in QR codes printed on the hardware.

### The OCR Workaround

This app takes a different approach:

1. The user opens Settings → WiFi on their iPhone
2. Reset LIFX bulbs appear in the network list as "LIFX \<model\> \<hex\>"
3. The user screenshots this page
4. The user shares the screenshot to the app (via Share Extension)
5. The app runs OCR using the Vision framework (`VNRecognizeTextRequest`)
6. The app filters recognized text for entries matching the "LIFX" prefix

The iOS WiFi settings page renders SSIDs as clean, high-contrast text on a white background, producing reliable OCR results. The Vision framework runs on-device with no network access.

Apple's Vision framework is a public API. Reading text from an image is not a restricted operation. This approach sidesteps the WiFi scanning restriction entirely.

### SSID Extraction

Vision may split a single SSID across multiple text observations. For example, "LIFX A19 D073D5" may appear as three separate observations: "LIFX", "A19", "D073D5".

The scanner (`SSIDScanner.swift`) handles this by:
1. Looking for observations containing "LIFX" as a complete SSID (single observation)
2. When "LIFX" appears standalone, gathering subsequent observations until one ending in 4-8 hex characters is found (the 3-octet device identifier)
3. Reassembling the fragments with spaces

### WiFi Switching

Uses `NEHotspotConfiguration` (NetworkExtension framework):
- Creates a configuration for the bulb's open SSID
- The system displays a confirmation prompt ("Join \<network\>?") — this cannot be suppressed
- After provisioning, removes the configuration, causing the phone to rejoin its preferred network

Requires the `com.apple.developer.networking.HotspotConfiguration` entitlement.

### SSID Verification

Uses `NEHotspotNetwork.fetchCurrent()` to verify the device connected to the expected network. Requires:
- `com.apple.developer.networking.wifi-info` entitlement
- Location Services authorization (when-in-use)

### Share Extension

`LIFXProvisionShare` is a separate target embedded in the main app. It:
- Appears in the iOS share sheet for images
- Shows a preview with Accept/Cancel buttons
- Saves the accepted image to an App Group container (`group.com.lifxprovision.shared`)
- The main app reads from this container on launch and when returning to foreground

### Credential Storage

The target SSID (network name) is saved to `@AppStorage` for quick re-use. The password is never persisted.

### Entitlements

**Main app** (`LIFXProvision.entitlements`):
- `com.apple.developer.networking.HotspotConfiguration` — WiFi switching
- `com.apple.developer.networking.wifi-info` — read current SSID
- `com.apple.security.application-groups` — share data with extension

**Share extension** (`LIFXProvisionShare.entitlements`):
- `com.apple.security.application-groups` — share data with main app

### Distribution

The app uses only public APIs and no private frameworks. However, Apple may reject it from the App Store because it demonstrates a workaround for their WiFi scanning restriction. Viable distribution channels:

- Build from source with Xcode (free Apple ID: 7-day sideload; $99/yr: 1-year sideload)
- TestFlight (requires paid developer account, up to 10,000 testers)
- AltStore or Sideloadly (no developer account required, periodic re-signing)

## References

- [tserong/lifx-hacks](https://github.com/tserong/lifx-hacks) — Python onboarding script, authoritative packet format reference
- [magicmonkey/lifxjs Protocol.md](https://github.com/magicmonkey/lifxjs/blob/master/Protocol.md) — reverse-engineered LIFX protocol documentation
- [zombience gist](https://gist.github.com/zombience/981d5920160fcca98e829082aa2d426f) — SetAccessPoint packet structure (caution: security type values differ from working implementations)

## AI Attribution

Development assisted by Claude (Anthropic).
