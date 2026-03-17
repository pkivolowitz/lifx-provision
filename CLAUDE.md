# LIFX WiFi Provisioning Tool — iOS App

## Bootstrap

Read `~/NAS/.claude/onboarding.md` first. All standing rules apply.

Project memory lives at: `~/NAS/.claude/projects/-Users-perrykivolowitz-lifx-provision/memory/`

## Session Startup Checklist

1. Run `hostname` — announce yourself by machine name
2. Verify NAS: `ls ~/NAS/.claude/projects/-Users-perrykivolowitz-lifx-provision/memory/MEMORY.md`
3. Read this file (CLAUDE.md) — project-specific standards
4. Read MEMORY.md — standing rules and active mandates
5. Pull from staging before starting work: `git pull staging master`

## Project-Specific Rules

- **iOS SwiftUI app** — targets iPhone, iOS 16+
- **Standalone tool** — not part of GlowUp. No code from the GlowUp codebase.
- **Perry will NOT test this** — he won't change his WiFi password (dozens of IoT devices)
- **Community will test** — code must be clear enough for strangers to audit and trust
- **Security is paramount** — this tool handles WiFi credentials. No shortcuts, no logging passwords, no writing credentials to disk.
- **NEVER mention CLAUDE or LAUDE in commit messages** — legal issue. AI attribution goes in MANUAL.md only.
- **Expansive commit messages** — every high-level change gets its own commit
- **ONE COMMAND AT A TIME** — never chain shell instructions

## Code Standards

- Swift doc comments (`///`) on all public types, methods, properties
- No magic numbers — constants in `Constants.swift`
- Code to be bullet and idiot proofed — community users with varying skill levels

## Architecture

Xcode project: `LIFXProvision.xcodeproj`

### Sources/
- `LIFXProvisionApp.swift` — @main app entry point
- `Views/ContentView.swift` — root view: credential entry, screenshot import, provisioning status
- `Services/SSIDScanner.swift` — Vision framework OCR: extract "LIFX Bulb-*" SSIDs from screenshots
- `Services/WiFiConnector.swift` — NEHotspotConfiguration: connect to bulb AP, reconnect to home
- `Services/BulbProvisioner.swift` — TLS to 172.16.0.1:56700, send SetAccessPoint
- `Services/Orchestrator.swift` — bulk loop: for each bulb, connect → provision → reconnect → verify
- `Protocol/LIFXPacket.swift` — LIFX protocol packet construction
- `Protocol/Constants.swift` — protocol constants, security types
- `Models/BulbInfo.swift` — bulb model with provisioning status

### Resources/
- `Assets.xcassets` — app icon, accent color
- `LIFXProvision.entitlements` — HotspotConfiguration capability

### iOS Strategy: Sidestep Apple's WiFi Scanning Lockdown

Apple blocks programmatic WiFi scanning. This app uses Perry's workaround:
1. User screenshots Settings → WiFi (shows "LIFX Bulb-*" APs)
2. User imports screenshot into the app (photo picker)
3. App OCRs the image with Vision framework (VNRecognizeTextRequest)
4. Extracts "LIFX Bulb-*" SSIDs from the OCR text
5. Connects to each via NEHotspotConfiguration and provisions

## Key Protocol Details

- Bulb AP mode: 172.16.0.1:56700 over TLS
- SetAccessPoint: message type 305
- Payload: 36-byte header + 1-byte interface + 32-byte SSID + 64-byte password + 1-byte security
- Security types: 0x01=Open, 0x02=WEP, 0x03=WPA2-AES, 0x04=WPA2-TKIP, 0x05=WPA2-Mixed

## References

- [tserong/lifx-hacks](https://github.com/tserong/lifx-hacks) — working onboarding implementation
- [zombience gist](https://gist.github.com/zombience/981d5920160fcca98e829082aa2d426f) — SetAccessPoint packet structure
- [lifxjs Protocol.md](https://github.com/magicmonkey/lifxjs/blob/master/Protocol.md) — reverse-engineered protocol
