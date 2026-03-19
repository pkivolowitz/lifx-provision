Copyright (c) 2026 Perry Kivolowitz — MIT License (see [LICENSE](LICENSE))

# LIFX Bulk WiFi Provisioning Tool

Provision LIFX smart devices with new WiFi credentials after a hardware reset. One command (macOS) or a few taps (iOS) replaces the tedious per-device process through the LIFX app.

## The Problem

Changing your WiFi password requires resetting every LIFX device individually (power cycle 5 times each), then re-provisioning each one through the LIFX app. With 30+ devices this takes hours.

## What This Tool Does

Automates everything after the hardware reset. You still physically reset each device (unavoidable — hardware operation), but provisioning is reduced to a single command or a few taps.

See [MANUAL.md](MANUAL.md) for detailed platform guides, troubleshooting, and the full technical reference.

## Platforms

| Platform | Discovery | Provisioning | Distribution |
|----------|-----------|-------------|--------------|
| **macOS CLI** | User reads System Settings → WiFi | Full | Build from source. No account required. |
| **iOS app** | Screenshot OCR (see below) | Full | Requires Mac + free Apple ID to sideload. |

Linux, Windows, and Android implementations are straightforward but not yet built. See [Platform Notes](#platform-notes).

## macOS Quick Start

### One-Time Setup

1. Open **Terminal** (press Cmd+Space, type "Terminal", press Enter)
2. If prompted to install developer tools, click **Install** and wait
3. Clone and build:

```
git clone https://github.com/pkivolowitz/lifx-provision.git
```
```
cd lifx-provision
```
```
swiftc -O -framework Network -framework Security cli/lifx-provision.swift -o lifx-provision
```

No Apple Developer account. No code signing. No special permissions.

### Provisioning Your Devices

1. Reset your devices: flip the light switch off and on 5 times. Each device flashes colors when reset.
2. Open **System Settings → WiFi** — you will see entries like "LIFX A19 D073D5". These are your reset devices.
3. Create a JSON file listing your devices (e.g., `my-bulbs.json`):

```json
{
  "bulbs": [
    "LIFX A19 D073D5",
    "LIFX Mini White AB12CD"
  ]
}
```

4. Run:

```
./lifx-provision --ssid "YourWiFiName" --config my-bulbs.json
```

5. The tool prompts for your WiFi password (never shown on screen, never in shell history).
6. Your Mac will briefly disconnect from WiFi as it talks to each device. This is normal.
7. When it says "Done", your devices are on your network.

Not every device may succeed on the first try. Remove the ones that worked from your config file and run again — the rest are still waiting in AP mode.

You can also specify devices directly:

```
./lifx-provision --ssid "YourWiFiName" --bulb "LIFX A19 D073D5"
```

Or combine both:

```
./lifx-provision --ssid "YourWiFiName" --config my-bulbs.json --bulb "LIFX Color E8F012"
```

Dry run (shows what would happen):

```
./lifx-provision --ssid "YourWiFiName" --bulb "LIFX A19 D073D5" --dry-run
```

Security type (default WPA2-AES, almost certainly correct for your network):

```
./lifx-provision --ssid "YourWiFiName" --security wpa2-mixed --bulb "LIFX A19 D073D5"
```

### What Happens

For each device the tool:
1. Switches your Mac's WiFi to the device's AP
2. Sends new credentials over TLS to 172.16.0.1:56700
3. Returns to your home network
4. Moves to the next device

The tool reports step-by-step progress (WiFi switch, DHCP, TLS send) with specific error messages if anything fails.

## iOS App

### Why an App

Apple does not provide any API for scanning WiFi networks on iOS. The LIFX app works around this with QR codes. This app uses a different approach: you screenshot the WiFi settings page and the app reads the device names from the image.

**If you have a Mac, the CLI is much easier to get running.** The iOS app requires building from source with Xcode and a free or paid Apple Developer account. See [MANUAL.md](MANUAL.md) for details.

### Quick Start

1. Open `LIFXProvision.xcodeproj` in Xcode
2. Select your iPhone, press Run (Cmd+R)
3. Trust the developer profile on your iPhone (Settings → General → VPN & Device Management)
4. Reset your devices, screenshot Settings → WiFi, share to the app
5. Enter your WiFi credentials and provision

## How It Works

After a hardware reset (power cycle 5 times), a LIFX device enters AP mode — broadcasting an open WiFi network named "LIFX \<model\> \<hex ID\>" and running a TLS server at 172.16.0.1:56700. The tool connects to this AP, sends a 134-byte SetAccessPoint packet with your WiFi credentials, and the device reboots onto your network.

The protocol is reverse-engineered and undocumented by LIFX. Packet format was verified against the [tserong/lifx-hacks](https://github.com/tserong/lifx-hacks) reference implementation. Full protocol details are in [MANUAL.md](MANUAL.md#technical-reference).

## Security

- Credentials are sent over TLS (encrypted) directly to the device
- The WiFi password is prompted interactively — never written to disk, never in shell history, never logged
- The config file contains only device names, never credentials
- The tool works entirely offline
- Fully open source — read every line before trusting it

## Platform Notes

### macOS WiFi Scanning

macOS has a WiFi scanning API (CoreWLAN), but Apple requires Location Services authorization. CLI tools cannot obtain this on modern macOS — Apple redacts all WiFi data from unsigned processes. The user reads device SSIDs from System Settings → WiFi instead.

### iOS WiFi Scanning

Apple provides no public API for WiFi scanning on iOS. This app works around the limitation by having the user screenshot the WiFi settings page. The Vision framework extracts text from the screenshot on-device with no network access.

### Other Platforms (Not Yet Implemented)

The provisioning protocol is platform-independent. Only the WiFi switching layer varies:

- **Linux**: `nmcli` for scanning and switching. No restrictions. Simplest platform.
- **Windows**: `netsh wlan show networks` / `netsh wlan connect`. No restrictions.
- **Android**: `WifiManager.getScanResults()` (requires location permission). Full automation possible.

## Limitations

- Hardware reset is always required (no way to change WiFi on a connected device)
- Protocol is reverse-engineered — LIFX firmware updates could break compatibility
- macOS CLI cannot scan for devices automatically (Apple privacy restriction)
- iOS app cannot be distributed through the App Store
- One WiFi radio means the host machine is briefly offline during each device
- Some devices may need a second provisioning attempt

## License

MIT — see [LICENSE](LICENSE)

## AI Attribution

Development assisted by Claude (Anthropic).
