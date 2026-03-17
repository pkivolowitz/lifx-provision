# LIFX Bulk WiFi Provisioning Tool

Provision LIFX smart bulbs with new WiFi credentials after a hardware reset. One command (macOS) or a few taps (iOS) replaces the tedious per-bulb process through the LIFX app.

## The Problem

Changing your WiFi password requires resetting every LIFX bulb individually (power cycle 5 times each), then re-provisioning each one through the LIFX app. With 30+ bulbs this takes hours.

## What This Tool Does

Automates everything after the hardware reset. You still physically reset each bulb (unavoidable — hardware operation), but provisioning is reduced to a single command or a few taps.

## Platforms

| Platform | Discovery | Provisioning | Distribution |
|----------|-----------|-------------|--------------|
| **macOS CLI** | User reads WiFi menu bar | Full | Build from source. No account required. |
| **iOS app** | Screenshot OCR (see below) | Full | Requires Mac + free Apple ID to sideload. |

Linux, Windows, and Android implementations are straightforward but not yet built. See [Platform Notes](#platform-notes).

## macOS — For Non-Technical Users

You do not need to be a programmer. You need a Mac with WiFi.

### One-Time Setup

1. Open **Terminal** (press Cmd+Space, type "Terminal", press Enter)
2. If prompted to install developer tools, click **Install** and wait
3. Copy and paste this entire block into Terminal, then press Enter:

```
cd /tmp && curl -O https://raw.githubusercontent.com/pkivolowitz/lifx-provision/master/cli/lifx-provision.swift && swiftc -O -framework Network -framework Security lifx-provision.swift -o lifx-provision && mv lifx-provision /usr/local/bin/ && echo "Done — lifx-provision is installed."
```

(Replace the URL above with the actual raw URL once the repository is published.)

### Provisioning Your Bulbs

1. Reset your bulbs: flip the light switch off and on 5 times. Each bulb flashes colors when reset.
2. Open **System Settings → WiFi** (the menu bar WiFi dropdown closes when you click away — use the full settings window instead)
3. You will see entries like "LIFX A19 D073D5" — these are your reset bulbs. Write them down.
4. Open **Terminal** and type (replacing the values with your own):

```
lifx-provision --ssid "YourWiFiName" --password "YourWiFiPassword" --bulb "LIFX A19 D073D5"
```

For multiple bulbs, add more `--bulb` entries:

```
lifx-provision --ssid "YourWiFiName" --password "YourWiFiPassword" --bulb "LIFX A19 D073D5" --bulb "LIFX Mini White AB12CD"
```

5. Your Mac will briefly disconnect from WiFi as it talks to each bulb. This is normal.
6. When it says "Done", your bulbs are on your network.

## macOS CLI — Technical Details

### Requirements

- macOS with WiFi
- Swift compiler (included with Xcode Command Line Tools)

### Install

```
xcode-select --install   # if you don't have Swift already
cd cli
swiftc -O -framework Network -framework Security lifx-provision.swift -o lifx-provision
```

No Apple Developer account. No code signing. No permissions.

### Usage

1. Reset your bulbs (power cycle 5 times each — they flash to confirm)
2. Open System Settings → WiFi — note the "LIFX ..." SSIDs (use the settings window, not the menu bar dropdown which closes when you click away)
3. Run:

```
./lifx-provision --ssid "YourNetwork" --password "YourPassword" \
  --bulb "LIFX A19 D073D5"
```

Multiple bulbs:

```
./lifx-provision --ssid "YourNetwork" --password "YourPassword" \
  --bulb "LIFX A19 D073D5" \
  --bulb "LIFX Mini White AB12CD" \
  --bulb "LIFX Color E8F012"
```

Dry run (shows what would happen):

```
./lifx-provision --ssid "YourNetwork" --password "YourPassword" \
  --bulb "LIFX A19 D073D5" --dry-run
```

Security type (default WPA2-AES):

```
./lifx-provision --ssid "YourNetwork" --password "YourPassword" \
  --bulb "LIFX A19 D073D5" --security wpa2-mixed
```

### What Happens

For each bulb the tool:
1. Switches your Mac's WiFi to the bulb's AP
2. Sends new credentials over TLS
3. Moves to the next bulb
4. Reconnects to your home network when done

Your Mac will be offline briefly during each bulb (a few seconds).

## iOS App

### Why an App

Apple does not provide any API for scanning WiFi networks on iOS. The LIFX app works around this with QR codes. This app uses a different approach: you screenshot the WiFi settings page and the app reads the bulb names from the image.

### Requirements

- iPhone running iOS 16+
- A Mac with Xcode (to build and install the app)
- Free Apple ID (sideloaded apps expire after 7 days) or paid Apple Developer account (1 year)

### Install

1. Open `LIFXProvision.xcodeproj` in Xcode
2. Select your iPhone as the destination
3. Press Run (Cmd+R)
4. Trust the developer profile on your iPhone (Settings → General → VPN & Device Management)

### Usage

1. Reset your bulbs (power cycle 5 times each)
2. Open Settings → WiFi on your iPhone — you'll see "LIFX ..." entries
3. Screenshot that page
4. Share the screenshot to "LIFX Provision" (it appears in the share sheet)
5. Confirm the screenshot in the app
6. The app extracts bulb names via OCR
7. Tap a bulb, enter your WiFi name and password, tap Provision
8. Accept the system prompt to join the bulb's network
9. The app sends credentials, then returns to your home network

The app saves your WiFi network name (not the password) for quick re-use.

## How It Works

### Hardware Reset

LIFX bulbs cannot change WiFi credentials while connected to a network. The only path is:

1. Power cycle the bulb 5 times (on-off-on-off-on-off-on-off-on-off-on)
2. The bulb flashes colors to confirm reset
3. It enters AP mode, broadcasting a WiFi network named "LIFX \<model\> \<hex ID\>"
4. The bulb's AP serves 172.16.0.1 on port 56700 over TLS

This physical reset step cannot be automated. The tool handles everything after it.

### Provisioning Protocol

The tool connects to the bulb's AP over TLS (port 56700, self-signed certificate) and sends a single 134-byte SetAccessPoint packet containing the target WiFi name, password, and security type. The bulb reboots and joins the specified network.

The protocol is reverse-engineered and undocumented by LIFX. Packet format was verified against the [tserong/lifx-hacks](https://github.com/tserong/lifx-hacks) reference implementation.

### Security

- Credentials are sent over TLS to the bulb
- The password is never written to disk (iOS saves the network name only, not the password)
- The bulb's AP is open during provisioning — keep the window short
- The TLS certificate is self-signed by the bulb; the tool accepts it without verification

## Platform Notes

### macOS WiFi Scanning

macOS has a WiFi scanning API (CoreWLAN), but Apple requires Location Services authorization to use it. On modern macOS, CLI tools cannot obtain this authorization — Apple redacts all WiFi data (SSIDs, BSSIDs, MAC addresses) from unsigned and CLI processes, including under sudo. The macOS CLI therefore requires the user to read bulb SSIDs from the WiFi menu bar.

### iOS WiFi Scanning

Apple provides no public API for scanning WiFi networks on iOS. The `NEHotspotHelper` API exists but requires a carrier-level entitlement that Apple does not grant to third-party developers. The `NEHotspotConfiguration` API can connect to a known SSID but cannot discover SSIDs.

This app works around the limitation by having the user screenshot the WiFi settings page. The iOS Settings WiFi page renders SSIDs as clean, high-contrast text — ideal for OCR. The Vision framework (`VNRecognizeTextRequest`) extracts text from the screenshot, and the app filters for entries matching the "LIFX" prefix. Apple cannot restrict reading text from an image.

### iOS Distribution

Apple would likely reject this app from the App Store because it demonstrates a workaround for their WiFi scanning restriction. Distribution options:

- **Sideload from Xcode** (free Apple ID): app expires after 7 days, must reinstall
- **Sideload from Xcode** (paid $99/yr developer account): app lasts 1 year
- **TestFlight**: up to 10,000 testers, lighter review than App Store
- **AltStore/Sideloadly**: users install via a computer without a developer account, must re-sign periodically
- **Build from source**: this repository, a Mac, and Xcode

### Other Platforms (Not Yet Implemented, Untested)

The provisioning protocol is platform-independent. Only the WiFi scanning and switching layer varies. These platforms are believed to be straightforward but have not been built or tested:

- **Linux**: `nmcli` for scanning and switching. No restrictions. Simplest platform.
- **Windows**: `netsh wlan show networks` for scanning, `netsh wlan connect` for switching. No restrictions.
- **Android**: `WifiManager.getScanResults()` for scanning (requires location permission, which is grantable). Full automation possible.

## SSID Format

LIFX bulbs in AP mode broadcast SSIDs in the format:

```
LIFX <model> <3 hex octets>
```

Examples: `LIFX A19 D073D5`, `LIFX Mini White AB12CD`, `LIFX Color 1000 E8F012`

## Limitations

- Hardware reset is always required (no way to change WiFi on a connected bulb)
- Protocol is reverse-engineered — LIFX firmware updates could break compatibility
- macOS CLI cannot scan for bulbs automatically (Apple privacy restriction)
- iOS app cannot be distributed through the App Store
- One WiFi radio means the host machine is briefly offline during each bulb

## License

MIT

## AI Attribution

Development assisted by Claude (Anthropic).
