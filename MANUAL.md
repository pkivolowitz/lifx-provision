Copyright (c) 2026 Perry Kivolowitz — MIT License (see [LICENSE](LICENSE))

# LIFX Bulk WiFi Provisioning Tool

Changed your WiFi password? Moved to a new router? Every LIFX bulb in your house just went dark, and the official app wants you to re-provision them one at a time. If you have a handful of bulbs, that's annoying. If you have thirty, it's a nightmare.

This tool tries to fix that. It sends your new WiFi credentials to each bulb in a fraction of the time to which are your accustomed. 

You manually reset your bulbs (we can't avoid that), run the tool, and they all come back online.

Don't be upset with LIFX because they don't offer a reset command. Imagine if someone broke into your network and reset all your light. The lack of the command is a feature not a bug.

Note that your WiFi password never leaves the device you are using this app on.

## Table of Contents

- [What You Need to Know First](#what-you-need-to-know-first)
- [Step 1: Reset Your Bulbs](#step-1-reset-your-bulbs)
- **Choose your platform:**
  - [iOS (iPhone)](#ios-iphone)
  - [macOS (Mac)](#macos-mac)
  - [Windows and Linux](#windows-and-linux)
- [Troubleshooting](#troubleshooting)
- [Security and Privacy](#security-and-privacy)
- [Technical Reference](#technical-reference) — protocol details for developers and contributors

---

## What You Need to Know First

Every LIFX bulb stores your WiFi network name and password internally. When you change your WiFi password (or get a new router), the bulbs can't connect anymore because they're still trying to use the old credentials.

The only way to give a bulb new WiFi credentials is:

1. **Reset the bulb** — this puts it into setup mode
2. **Send it your new WiFi details** — that's what this tool does

There is no way to skip the reset step. It's a hardware requirement, not a limitation of this tool. The good news: you can reset all your bulbs as you would anyway, then provision them all in one session rather than one-by-one.

---

## Step 1: Reset Your Bulbs

To reset a LIFX bulb, turn it off and on **five times in a row** using the physical light switch or power source. Wait about one second between each toggle. You'll know it worked when the bulb starts cycling through colors (red, green, blue, white). If the bulb is a monochrome light (one color like white), it will still do a little dance.

A reset bulb creates its own small WiFi network with a name like:

> LIFX White D073D5

The name always starts with "LIFX" followed by the bulb model and some letters/numbers that identify that specific bulb.

**You can reset as many bulbs as you like at the same time.** Each one will create its own WiFi network, and the tool will handle them one by one.

Once a bulb is reset, it stays in setup mode until it receives new WiFi credentials. There's no rush — take your time.

---

## iOS (iPhone)

**Heads up:** If you have access to a Mac, the [macOS version](#macos-mac) is much easier to get running. The iOS app works well once installed, but getting it onto your phone is a hassle because Apple would likely never allow it on the App Store — as it works around an iOS WiFi restriction that Apple enforces (cudos to us for thinking outside the box). You'll need to build it from source with Xcode, which means either a free Apple Developer account (app expires every 7 days and must be reinstalled) or a paid account ($99/year). If that doesn't scare you off, read on.

### What You Need

- An iPhone running iOS 16 or later
- A Mac with Xcode installed (there is no way around this)
- A free or paid Apple Developer account
- Your new WiFi network name and password

### Installing the App

1. Clone or download the source code onto your Mac
2. Open `LIFXProvision.xcodeproj` in Xcode
3. Select your Apple Developer account under Signing & Capabilities
4. Connect your iPhone (or select it as a wireless destination)
5. Build and run — Xcode will install the app on your phone

With a free account, the app expires after 7 days and you'll need to repeat this process. A paid developer account ($99/year) gives you a full year before re-signing. If you reset all your LIFX products within 7 days, you can avoid the paid subscription.

### Step by Step

1. **Reset your bulbs** using the power-cycling method described above.

2. **Open your iPhone's Settings app**, then tap **Wi-Fi**. You'll see your normal networks plus new entries starting with "LIFX" — one for each reset bulb. Don't tap on any of them.

3. **Take a screenshot** of the WiFi list. If you have many bulbs, scroll down and take additional screenshots to capture them all.

4. **Share the screenshot to the LIFX Provisioning app.** Tap the screenshot in your Photos, tap the Share button (the square with an arrow), and choose "LIFX Provision" from the list. Tap Accept in the preview.

5. **Open the LIFX Provisioning app.** You'll see the bulb names that were found in your screenshot.

6. **Enter your WiFi credentials.** Tap a bulb, then enter your WiFi network name and password. The network name is saved for convenience; the password is never stored.

7. **Tap Provision.** Your phone will briefly connect to the bulb's network (you'll see a system prompt asking to join — tap Join), send the credentials, then reconnect to your normal WiFi. The bulb will reboot and join your network.

8. **Repeat** for each bulb, or wait for bulk provisioning in a future update.

### Why Screenshots?

Apple does not allow any app to scan for WiFi networks. The official LIFX app gets around this with QR codes printed on the bulbs. This app takes a different approach: you screenshot the WiFi list, and the app reads the bulb names from the image using on-device text recognition. It's a workaround, but it's reliable and keeps everything on your device.

---

## macOS (Mac)

### What You Need

- A Mac running macOS 13 (Ventura) or later
- Xcode Command Line Tools installed (the tool will tell you how if you don't have them)
- Your new WiFi network name and password

### Building the Tool

Open Terminal (in Applications → Utilities) and run:

```
xcode-select --install
```

If you already have the command line tools, this will tell you so. If not, follow the prompts to install them.

Then download and build the provisioning tool:

```
git clone https://github.com/pkivolowitz/lifx-provision.git
```
```
cd lifx-provision
```
```
swiftc -O -framework Network -framework Security cli/lifx-provision.swift -o lifx-provision
```

This produces a single file called `lifx-provision` that you can run directly.

### Finding Your Bulbs

After resetting your bulbs, you need to find their network names:

1. Open **System Settings** (Apple menu → System Settings)
2. Click **Wi-Fi** in the sidebar
3. Look through the list of available networks for entries starting with "LIFX"
4. Write down (or remember) the full name of each bulb network

You'll pass these names to the tool in the next step.

### Provisioning

You can provide bulb names directly on the command line:

```
./lifx-provision --ssid "YourNetworkName" --bulb "LIFX A19 D073D5"
```

The tool will prompt you for your WiFi password. The password is always entered interactively — it never appears in your command line or shell history.

For multiple bulbs, you can repeat the `--bulb` flag, but a config file is easier. Create a JSON file (e.g., `my-bulbs.json`) listing your bulbs:

```json
{
  "bulbs": [
    "LIFX A19 D073D5",
    "LIFX BR30 A1B2C3",
    "LIFX White D512FA"
  ]
}
```

Copy-paste the bulb names from System Settings into this file — one per line, change each to match what you see. The file contains only bulb names, never credentials. Then run:

```
./lifx-provision --ssid "YourNetworkName" --config my-bulbs.json
```

You can also combine both — `--config` and `--bulb` flags together. All bulbs from both sources are provisioned in one run.

The tool will:
1. Prompt for your WiFi password
2. Save your current WiFi connection
3. Switch to the first bulb's network
4. Send your WiFi credentials to the bulb
5. Switch back to your normal WiFi
6. Repeat for each additional bulb

Your Mac will briefly disconnect from your WiFi during each bulb — this is normal. It reconnects automatically after each one.

### Security Types

Most home networks use WPA2 (the default). If your network uses a different security type, specify it with `--security`:

```
./lifx-provision --ssid "YourNetwork" --security wpa2-aes --bulb "LIFX A19 D073D5"
```

Available options: `open`, `wep`, `wpa-tkip`, `wpa-aes`, `wpa2-aes` (default), `wpa2-tkip`, `wpa2-mixed`

If you're not sure what your network uses, the default (`wpa2-aes`) is almost certainly correct.

---

## Windows and Linux

There is no Windows or Linux version of this tool yet. The provisioning protocol is the same on every platform — only the WiFi switching part is platform-specific.

If you're a developer interested in contributing a Windows or Linux port, see the [Technical Reference](#technical-reference) section for the full protocol specification. The key platform-specific pieces are:

- **Windows**: `netsh wlan connect name="SSID"` for WiFi switching, `netsh wlan show networks` for scanning
- **Linux**: `nmcli device wifi connect "SSID"` for WiFi switching, `nmcli device wifi list` for scanning

Linux is actually the easiest platform for this — `nmcli` provides unrestricted WiFi scanning and switching with no permission hurdles.

---

## Troubleshooting

### The bulb didn't cycle through colors after power-cycling

Make sure you're toggling the power source (wall switch or smart plug), not using the LIFX app or a voice assistant. The timing is about one second between each toggle. Some bulbs need a slightly slower rhythm — try two seconds between toggles.

### The bulb's WiFi network doesn't appear

Give it 30 seconds after the color cycle completes. If it still doesn't appear, try the reset again or manually refresh the listing. The bulb's network is an open WiFi network, so it will show up in any standard WiFi list.

### "Could not connect to bulb" error

The tool needs to connect to the bulb's WiFi network, which means temporarily leaving your normal WiFi. If the connection fails, try again — WiFi switching can occasionally take longer than expected, especially in environments with many networks.

### The bulb received credentials but didn't come back online

Double-check that you typed your WiFi network name and password correctly. The network name is case-sensitive. If the credentials were wrong, the bulb will remain offline — reset it again and re-provision with the correct details.

### macOS: "networksetup" permission prompt

The first time you run the tool, macOS may ask for permission to change your WiFi settings. This is normal — the tool needs to switch WiFi networks to reach each bulb.

---

## Security and Privacy

This tool handles your WiFi password. Here's how it protects you:

- **Your password is sent directly to the bulb over an encrypted (TLS) connection.** It never touches the internet.
- **Your password is never written to disk, logged, or stored** (the iOS app saves your network name for convenience, but never the password).
- **The tool is fully open source.** You can read every line of code before trusting it with your credentials.
- **The tool works entirely offline.** No network access is needed beyond the direct WiFi connection to each bulb.

The one thing to be aware of: during provisioning, your device connects to the bulb's open WiFi network. Someone within WiFi range could theoretically see that you're connected to a "LIFX" network, but the actual credentials are encrypted in transit.

---

## Technical Reference

This section documents the LIFX provisioning protocol for developers and contributors. If you're just trying to provision your bulbs, you don't need any of this.

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

### macOS CLI Implementation Notes

Single Swift file (`cli/lifx-provision.swift`). No external dependencies.

**WiFi switching** uses `networksetup` via `Process`:
- `networksetup -getairportnetwork en0` — read current SSID
- `networksetup -setairportnetwork en0 "SSID"` — join an open network
- `networksetup -setairportnetwork en0 "SSID" "password"` — join a secured network

Does not use CoreWLAN. Apple requires Location Services authorization for CoreWLAN, which is effectively unavailable to CLI tools on modern macOS.

**TLS** uses `NWConnection` (Network framework) with `NWProtocolTLS.Options`. Certificate verification is disabled via `sec_protocol_options_set_verify_block` to accept the bulb's self-signed certificate.

### iOS App Implementation Notes

**WiFi scanning workaround**: Apple provides no public API for WiFi scanning on iOS. This app screenshots the Settings → WiFi page and uses the Vision framework (`VNRecognizeTextRequest`) for on-device OCR. Vision may split a single SSID across multiple text observations; the scanner reassembles fragments by looking for the "LIFX" prefix and gathering subsequent observations until the hex device identifier is found.

**WiFi switching** uses `NEHotspotConfiguration` (NetworkExtension framework). The system displays a confirmation prompt per connection that cannot be suppressed.

**Entitlements required**:
- `com.apple.developer.networking.HotspotConfiguration` — WiFi switching
- `com.apple.developer.networking.wifi-info` — read current SSID
- `com.apple.security.application-groups` — share data between app and Share Extension

### References

- [tserong/lifx-hacks](https://github.com/tserong/lifx-hacks) — Python onboarding script, authoritative packet format reference
- [magicmonkey/lifxjs Protocol.md](https://github.com/magicmonkey/lifxjs/blob/master/Protocol.md) — reverse-engineered LIFX protocol documentation
- [zombience gist](https://gist.github.com/zombience/981d5920160fcca98e829082aa2d426f) — SetAccessPoint packet structure (caution: security type values differ from working implementations)

### Platform WiFi Capabilities

| Platform | Scan Networks | Switch Networks | Restrictions |
|----------|--------------|-----------------|--------------|
| iOS | No public API | `NEHotspotConfiguration` | Carrier entitlement for scanning; system prompt per connection |
| macOS | CoreWLAN (requires Location Services) | `networksetup` | CLI tools get redacted WiFi data without Location Services |
| Linux | `nmcli device wifi list` | `nmcli device wifi connect` | None — fully open |
| Windows | `netsh wlan show networks` | `netsh wlan connect` | None — fully open |
| Android | `WifiManager.getScanResults()` | `WifiNetworkSpecifier` | Requires location permission |

## AI Attribution

Development assisted by Claude (Anthropic).
