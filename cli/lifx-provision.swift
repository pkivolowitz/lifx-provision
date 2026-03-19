#!/usr/bin/env swift
/// LIFX bulk WiFi provisioning CLI for macOS.
/// Uses networksetup for WiFi switching (no Location Services needed).
/// User provides bulb SSIDs from the WiFi menu bar.

import Foundation
import Network

// MARK: - Constants

let LIFX_PORT: UInt16 = 56700
let LIFX_AP_IP = "172.16.0.1"
let HEADER_SIZE = 36
let SSID_SIZE = 32
let PASSWORD_SIZE = 64

enum SecurityType: UInt8, CustomStringConvertible {
    case open      = 0x01
    case wepPSK    = 0x02
    case wpaTKIP   = 0x03
    case wpaAES    = 0x04
    case wpa2AES   = 0x05
    case wpa2TKIP  = 0x06
    case wpa2Mixed = 0x07

    var description: String {
        switch self {
        case .open: return "Open"
        case .wepPSK: return "WEP"
        case .wpaTKIP: return "WPA-TKIP"
        case .wpaAES: return "WPA-AES"
        case .wpa2AES: return "WPA2-AES"
        case .wpa2TKIP: return "WPA2-TKIP"
        case .wpa2Mixed: return "WPA2-Mixed"
        }
    }
}

// MARK: - JSON Config

/// Structure for --config JSON file. Contains only bulb SSIDs — never credentials.
struct BulbConfig: Decodable {
    let bulbs: [String]
}

/// Reads bulb SSIDs from a JSON config file.
/// Expected format: { "bulbs": ["LIFX A19 D073D5", "LIFX BR30 A1B2C3"] }
func loadBulbConfig(path: String) -> [String]? {
    let url = URL(fileURLWithPath: path)
    guard let data = try? Data(contentsOf: url) else {
        print("Error: cannot read config file '\(path)'")
        return nil
    }
    guard let config = try? JSONDecoder().decode(BulbConfig.self, from: data) else {
        print("Error: invalid JSON in '\(path)' — expected { \"bulbs\": [\"LIFX ...\", ...] }")
        return nil
    }
    if config.bulbs.isEmpty {
        print("Error: config file contains no bulbs")
        return nil
    }
    return config.bulbs
}

// MARK: - Password Prompt

/// Prompts for password on stdin with echo disabled so it stays out of shell history and screen.
func promptPassword() -> String? {
    print("WiFi password: ", terminator: "")
    let oldSettings = enableRawMode()
    defer { restoreTerminal(oldSettings) }
    guard let password = readLine(strippingNewline: true) else { return nil }
    print("")  // newline after hidden input
    return password.isEmpty ? nil : password
}

/// Disables terminal echo for password entry.
func enableRawMode() -> termios {
    var old = termios()
    tcgetattr(STDIN_FILENO, &old)
    var new = old
    new.c_lflag &= ~UInt(ECHO)
    tcsetattr(STDIN_FILENO, TCSANOW, &new)
    return old
}

/// Restores terminal settings after password entry.
func restoreTerminal(_ settings: termios) {
    var s = settings
    tcsetattr(STDIN_FILENO, TCSANOW, &s)
}

// MARK: - Shell Helpers

@discardableResult
func shell(_ command: String) -> (output: String, status: Int32) {
    let task = Process()
    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = pipe
    task.launchPath = "/bin/zsh"
    task.arguments = ["-c", command]
    task.launch()
    task.waitUntilExit()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return (output, task.terminationStatus)
}

// MARK: - WiFi (networksetup)

func getWiFiDevice() -> String {
    // Find the WiFi hardware port
    let result = shell("networksetup -listallhardwareports")
    let lines = result.output.components(separatedBy: "\n")
    for (i, line) in lines.enumerated() {
        if line.contains("Wi-Fi") && i + 1 < lines.count {
            let deviceLine = lines[i + 1]
            if let device = deviceLine.components(separatedBy: ": ").last {
                return device
            }
        }
    }
    return "en0"
}

func currentSSID(device: String) -> String? {
    let result = shell("networksetup -getairportnetwork \(device)")
    // Output: "Current Wi-Fi Network: NetworkName" or "You are not associated..."
    if result.output.contains("Current Wi-Fi Network:") {
        return result.output.components(separatedBy: ": ").last
    }
    // Fallback: try ipconfig
    let ipResult = shell("ipconfig getsummary \(device) 2>/dev/null | grep '  SSID' | awk '{print $3}'")
    return ipResult.output.isEmpty ? nil : ipResult.output
}

func connectToNetwork(device: String, ssid: String, password: String? = nil) -> Bool {
    let cmd: String
    if let password = password {
        cmd = "networksetup -setairportnetwork \(device) \"\(ssid)\" \"\(password)\""
    } else {
        cmd = "networksetup -setairportnetwork \(device) \"\(ssid)\""
    }
    let result = shell(cmd)
    if result.status != 0 || result.output.contains("Error") {
        print("  networksetup error (exit \(result.status)): \(result.output)")
        return false
    }
    return true
}

// MARK: - Packet Construction

func buildSetAccessPoint(ssid: String, password: String, security: SecurityType = .wpa2AES) -> Data {
    let totalSize = HEADER_SIZE + 1 + SSID_SIZE + PASSWORD_SIZE + 1  // 134
    var packet = Data(count: totalSize)

    packet[0] = UInt8(totalSize & 0xFF)
    packet[1] = UInt8((totalSize >> 8) & 0xFF)
    packet[2] = 0x00
    packet[3] = 0x34
    packet[32] = 0x31
    packet[33] = 0x01
    packet[36] = 0x02

    let ssidBytes = Array(ssid.utf8.prefix(SSID_SIZE))
    for (i, b) in ssidBytes.enumerated() {
        packet[37 + i] = b
    }

    let passBytes = Array(password.utf8.prefix(PASSWORD_SIZE))
    for (i, b) in passBytes.enumerated() {
        packet[69 + i] = b
    }

    packet[133] = security.rawValue
    return packet
}

// MARK: - TLS Provisioning

func provisionBulb(ssid: String, password: String, security: SecurityType) -> Bool {
    let packet = buildSetAccessPoint(ssid: ssid, password: password, security: security)
    let semaphore = DispatchSemaphore(value: 0)
    var success = false

    let tlsOptions = NWProtocolTLS.Options()
    sec_protocol_options_set_verify_block(
        tlsOptions.securityProtocolOptions,
        { _, _, completionHandler in completionHandler(true) },
        .global()
    )

    let tcpOptions = NWProtocolTCP.Options()
    tcpOptions.connectionTimeout = 10

    let params = NWParameters(tls: tlsOptions, tcp: tcpOptions)
    let connection = NWConnection(
        host: NWEndpoint.Host(LIFX_AP_IP),
        port: NWEndpoint.Port(rawValue: LIFX_PORT)!,
        using: params
    )

    connection.stateUpdateHandler = { state in
        switch state {
        case .preparing:
            print("  TLS: preparing connection...")
        case .waiting(let error):
            print("  TLS: waiting — \(error.localizedDescription)")
        case .ready:
            print("  TLS: connected, sending \(packet.count)-byte packet...")
            connection.send(content: packet, completion: .contentProcessed { error in
                if let error {
                    print("  Send failed: \(error.localizedDescription)")
                    connection.cancel()
                    semaphore.signal()
                } else {
                    print("  Packet sent, waiting for bulb to process...")
                    DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) {
                        success = true
                        connection.cancel()
                        semaphore.signal()
                    }
                }
            })
        case .failed(let error):
            print("  TLS connection failed: \(error.localizedDescription)")
            connection.cancel()
            semaphore.signal()
        case .cancelled:
            break
        default:
            break
        }
    }

    connection.start(queue: .global())
    let waitResult = semaphore.wait(timeout: .now() + 20.0)
    if waitResult == .timedOut {
        print("  Timed out after 20 seconds — bulb did not respond")
        connection.cancel()
    }
    return success
}

// MARK: - Main

func printUsage() {
    print("""
    lifx-provision — LIFX bulk WiFi provisioning for macOS

    Usage:
      lifx-provision --ssid <network> --bulb <name> [--bulb <name2>...]
      lifx-provision --ssid <network> --config <file.json>

    Options:
      --ssid <name>        Target WiFi network name (required)
      --security <type>    Security type: open, wpa2-aes (default), wpa2-tkip, wpa2-mixed
      --bulb <name>        LIFX device SSID to provision (repeatable, must start with "LIFX ")
      --config <file>      JSON file with device SSIDs (see below)
      --dry-run            Show what would happen without doing it

    The password is always prompted interactively so it never appears in
    your shell history or on screen.

    The --config file contains only device names, never credentials:
      { "bulbs": ["LIFX A19 D073D5", "LIFX BR30 A1B2C3"] }

    Device SSIDs are visible in System Settings → WiFi when devices are
    in AP mode (after hardware reset — power cycle 5 times).

    Examples:
      lifx-provision --ssid "MyNetwork" --bulb "LIFX A19 D073D5"
      lifx-provision --ssid "MyNetwork" --config my-bulbs.json
    """)
}

var targetSSID: String?
var configPath: String?
var security: SecurityType = .wpa2AES
var bulbSSIDs: [String] = []
var dryRun = false

var args = CommandLine.arguments.dropFirst()
while let arg = args.first {
    args = args.dropFirst()
    switch arg {
    case "--ssid":
        targetSSID = args.first
        args = args.dropFirst()
    case "--security":
        if let val = args.first {
            args = args.dropFirst()
            switch val {
            case "open": security = .open
            case "wpa2-aes": security = .wpa2AES
            case "wpa2-tkip": security = .wpa2TKIP
            case "wpa2-mixed": security = .wpa2Mixed
            default:
                print("Unknown security type: \(val)")
                exit(1)
            }
        }
    case "--bulb":
        if let name = args.first {
            if !name.hasPrefix("LIFX ") {
                print("WARNING: '\(name)' doesn't look like a LIFX device SSID (expected 'LIFX ...')")
                print("  Did you mean --config \(name)?")
                exit(1)
            }
            bulbSSIDs.append(name)
            args = args.dropFirst()
        }
    case "--config":
        configPath = args.first
        args = args.dropFirst()
    case "--dry-run":
        dryRun = true
    case "--help", "-h":
        printUsage()
        exit(0)
    default:
        print("Unknown option: \(arg)")
        printUsage()
        exit(1)
    }
}

// Load bulbs from config file if provided
if let path = configPath {
    guard let configBulbs = loadBulbConfig(path: path) else {
        exit(1)
    }
    bulbSSIDs.append(contentsOf: configBulbs)
}

if targetSSID == nil || bulbSSIDs.isEmpty {
    printUsage()
    exit(1)
}

// Prompt for password interactively — keeps it out of shell history
guard let targetPassword = promptPassword() else {
    print("Error: password is required")
    exit(1)
}

let device = getWiFiDevice()
let homeSSID = currentSSID(device: device)
print("WiFi device: \(device)")
print("Current network: \(homeSSID ?? "unknown")")
print("Bulbs to provision: \(bulbSSIDs.count)")
print("Target network: \(targetSSID!) (\(security))")

if dryRun {
    print("\nDry run — would provision:")
    for ssid in bulbSSIDs {
        print("  \(ssid)")
    }
    exit(0)
}

var succeeded = 0
var failed = 0

for bulbSSID in bulbSSIDs {
    print("\n--- \(bulbSSID) ---")

    print("  Step 1/3: Connecting to \(bulbSSID)...")
    guard connectToNetwork(device: device, ssid: bulbSSID) else {
        print("  FAILED at step 1 — could not switch WiFi to bulb's network")
        print("  Check that the bulb is still in AP mode and within range")
        failed += 1
        continue
    }

    print("  Step 2/3: Waiting for DHCP...")
    sleep(4)

    let current = currentSSID(device: device)
    if current == bulbSSID {
        print("  Connected to \(bulbSSID)")
    } else {
        print("  WARNING: expected '\(bulbSSID)' but connected to '\(current ?? "none")'")
        print("  This usually means the WiFi switch didn't complete — trying anyway")
    }

    print("  Step 3/3: Sending credentials via TLS...")
    if provisionBulb(ssid: targetSSID!, password: targetPassword, security: security) {
        print("  SUCCESS — \(bulbSSID) provisioned")
        succeeded += 1
    } else {
        print("  FAILED at step 3 — could not send credentials to bulb")
        print("  The TLS connection to 172.16.0.1:56700 did not complete")
        failed += 1
    }

    sleep(2)
}

// Return to home network
print("\nReconnecting to home network...")
if let home = homeSSID {
    if connectToNetwork(device: device, ssid: home) {
        print("Back on \(home)")
    } else {
        print("WARNING: Could not rejoin \(home) — reconnect manually")
    }
} else {
    print("Reconnect to your network manually")
}

print("\nDone. \(succeeded) provisioned, \(failed) failed.")
