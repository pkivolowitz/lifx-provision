# LIFX WiFi Provisioning Tool — iOS App + macOS CLI

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

- **Standalone tool** — not part of GlowUp. No code from the GlowUp codebase.
- **Perry will NOT test in bulk** — has one bulb to test with
- **Community will test at scale** — code must be clear enough for strangers to audit and trust
- **Security is paramount** — this tool handles WiFi credentials. No shortcuts, no logging passwords, no writing credentials to disk.
- **NEVER mention CLAUDE or LAUDE in commit messages** — legal issue. AI attribution goes in MANUAL.md only.
- **Expansive commit messages** — every high-level change gets its own commit
- **ONE COMMAND AT A TIME** — never chain shell instructions

## Code Standards

- Swift doc comments (`///`) on all public types, methods, properties
- No magic numbers — constants in `Constants.swift` (iOS) or top of file (CLI)
- Code to be bullet and idiot proofed — community users with varying skill levels

## Architecture

### iOS App — `LIFXProvision.xcodeproj`

SwiftUI app with Share Extension. Sidesteps Apple's WiFi scanning lockdown
via screenshot OCR (Perry's insight).

**Sources/**
- `LIFXProvisionApp.swift` — @main app entry point
- `Views/ContentView.swift` — root view: screenshot, OCR results, provisioning status
- `Views/CredentialSheet.swift` — target SSID + password entry with saved quick-fill
- `Services/SSIDScanner.swift` — Vision framework OCR: extract "LIFX <model> <hex>" SSIDs
- `Services/WiFiConnector.swift` — NEHotspotConfiguration: connect to bulb AP, reconnect to home
- `Services/BulbProvisioner.swift` — TLS to 172.16.0.1:56700, send SetAccessPoint
- `Services/Orchestrator.swift` — bulk loop (not yet implemented)
- `Protocol/LIFXPacket.swift` — LIFX protocol packet construction
- `Protocol/Constants.swift` — protocol constants, security types (verified against reference)
- `Models/BulbInfo.swift` — bulb model with provisioning status

**Share Extension** (`LIFXProvisionShare/`)
- Receives screenshots via iOS share sheet with confirm UI
- Saves to App Group container for main app to pick up

**iOS Flow:** Screenshot Settings → WiFi → share to app → OCR extracts SSIDs → tap bulb → enter credentials → provision via TLS → return to home network

### macOS CLI — `cli/`

Single-file Swift CLI. No CoreWLAN (requires Location Services, effectively
blocked for CLI tools). Uses `networksetup` for WiFi switching.

- `lifx-provision.swift` — complete CLI tool
- `LIFXProvisionCLI.app/` — .app bundle wrapper (if CoreWLAN ever needed)

**Build:** `swiftc -O -framework Network -framework Security cli/lifx-provision.swift -o cli/lifx-provision`

**macOS Flow:** User reads bulb SSIDs from WiFi menu bar → passes via `--bulb` flags → tool switches WiFi, provisions via TLS, returns to home network

### Platform WiFi Scanning Reality

- **iOS**: Completely blocked. No public API. OCR workaround required.
- **macOS**: CoreWLAN exists but requires Location Services. Apple redacts all WiFi data (SSIDs, BSSIDs, MACs) from CLI tools, even with sudo. User reads WiFi menu bar instead.
- **Linux**: `nmcli` — fully open, no restrictions.
- **Windows**: `netsh wlan show networks` — fully open.
- **Android**: `WifiManager.getScanResults()` — needs location permission but grantable.

## Key Protocol Details

Verified against tserong/lifx-hacks reference implementation (NOT the zombience gist).

- Bulb AP mode: 172.16.0.1:56700 over TLS (self-signed cert)
- SetAccessPoint: message type 305
- Header: 36 bytes, frame field 0x3400 (protocol=1024, addressable=1, tagged=1), source=0
- Payload: 1-byte interface (0x02) + 32-byte SSID + 64-byte password + 1-byte security
- Total packet: 134 bytes
- SSID format: "LIFX <model> <3 hex octets>" with spaces
- Security types: 0x01=Open, 0x02=WEP, 0x03=WPA-TKIP, 0x04=WPA-AES, 0x05=WPA2-AES, 0x06=WPA2-TKIP, 0x07=WPA2-Mixed

## References

- [tserong/lifx-hacks](https://github.com/tserong/lifx-hacks) — authoritative reference implementation
- [zombience gist](https://gist.github.com/zombience/981d5920160fcca98e829082aa2d426f) — packet structure (WARNING: security type values are wrong)
- [lifxjs Protocol.md](https://github.com/magicmonkey/lifxjs/blob/master/Protocol.md) — reverse-engineered protocol
