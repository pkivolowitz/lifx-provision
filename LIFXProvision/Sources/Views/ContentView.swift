// Copyright (c) 2026 Perry Kivolowitz — MIT License (see LICENSE)
/// Root view — displays screenshot, runs OCR, shows discovered bulb SSIDs,
/// and provisions bulbs with new WiFi credentials.

import SwiftUI

struct ContentView: View {
    @State private var screenshotImage: UIImage?
    @State private var discoveredSSIDs: [String] = []
    @State private var rawOCRText: [String] = []
    @State private var scanError: String?
    @State private var isScanning: Bool = false
    @State private var showRawOCR: Bool = false

    @State private var wifiStatus: String?
    @State private var isConnecting: Bool = false
    @State private var connectResult: ConnectResult?

    // Credential sheet
    @State private var showCredentialSheet: Bool = false
    @State private var selectedBulbSSID: String = ""
    @State private var targetSSID: String = ""
    @State private var targetPassword: String = ""

    @AppStorage("savedTargetSSID") private var savedTargetSSID: String = ""

    private let wifiConnector = WiFiConnector()

    enum ConnectResult {
        case success(String)
        case failure(String)
    }

    var body: some View {
        NavigationStack {
            List {
                if let image = screenshotImage {
                    Section("Screenshot") {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .listRowInsets(EdgeInsets())
                    }
                }

                if isScanning {
                    Section {
                        HStack {
                            ProgressView()
                            Text("Scanning for LIFX bulbs...")
                                .padding(.leading, 8)
                        }
                    }
                }

                if !discoveredSSIDs.isEmpty {
                    Section("Discovered Bulbs") {
                        ForEach(discoveredSSIDs, id: \.self) { ssid in
                            Button {
                                selectedBulbSSID = ssid
                                targetPassword = ""
                                if !savedTargetSSID.isEmpty {
                                    targetSSID = savedTargetSSID
                                }
                                showCredentialSheet = true
                            } label: {
                                HStack {
                                    Label(ssid, systemImage: "lightbulb.fill")
                                    Spacer()
                                    if isConnecting {
                                        ProgressView()
                                    } else {
                                        Image(systemName: "arrow.right.circle")
                                            .foregroundStyle(.blue)
                                    }
                                }
                            }
                            .disabled(isConnecting)
                        }
                    }
                }

                if isConnecting, let status = wifiStatus {
                    Section("Provisioning") {
                        HStack {
                            ProgressView()
                            Text(status)
                                .padding(.leading, 8)
                        }
                    }
                }

                if let result = connectResult {
                    Section("Result") {
                        switch result {
                        case .success(let message):
                            Label(message, systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        case .failure(let message):
                            Label(message, systemImage: "xmark.circle.fill")
                                .foregroundStyle(.red)
                        }
                    }
                }

                if let error = scanError {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }

                if !rawOCRText.isEmpty && showRawOCR {
                    Section("Raw OCR Output") {
                        ForEach(Array(rawOCRText.enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(.system(.caption, design: .monospaced))
                        }
                    }
                }

                if screenshotImage == nil {
                    Section {
                        VStack(spacing: 16) {
                            Image(systemName: "wifi")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)
                            Text("No Screenshot")
                                .font(.title2)
                            Text("Share a screenshot of Settings → WiFi to get started")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                }
            }
            .navigationTitle("LIFX Provision")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !rawOCRText.isEmpty {
                        Button(showRawOCR ? "Hide Debug" : "Debug") {
                            showRawOCR.toggle()
                        }
                        .font(.caption)
                    }
                }
            }
            .sheet(isPresented: $showCredentialSheet) {
                CredentialSheet(
                    bulbSSID: selectedBulbSSID,
                    targetSSID: $targetSSID,
                    targetPassword: $targetPassword,
                    savedTargetSSID: $savedTargetSSID
                ) {
                    savedTargetSSID = targetSSID
                    showCredentialSheet = false
                    provisionBulb(bulbSSID: selectedBulbSSID,
                                  targetSSID: targetSSID,
                                  password: targetPassword)
                } onCancel: {
                    showCredentialSheet = false
                }
            }
        }
        .onAppear { loadAndScan() }
        .onReceive(
            NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
        ) { _ in
            loadAndScan()
        }
    }

    // MARK: - Actions

    private func loadAndScan() {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.lifxprovision.shared"
        ) else { return }

        let fileURL = containerURL.appendingPathComponent("shared_screenshot.png")

        guard let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data) else { return }

        screenshotImage = image
        scanForBulbs(image: image)
    }

    private func scanForBulbs(image: UIImage) {
        isScanning = true
        scanError = nil
        discoveredSSIDs = []
        rawOCRText = []

        Task {
            do {
                let result = try await SSIDScanner.scan(image: image)
                await MainActor.run {
                    discoveredSSIDs = result.ssids
                    rawOCRText = result.rawText
                    isScanning = false
                    if result.ssids.isEmpty {
                        scanError = "No LIFX bulb SSIDs found in screenshot"
                    }
                }
            } catch {
                await MainActor.run {
                    scanError = "OCR failed: \(error.localizedDescription)"
                    isScanning = false
                }
            }
        }
    }

    private func provisionBulb(bulbSSID: String, targetSSID: String, password: String) {
        isConnecting = true
        connectResult = nil

        Task {
            do {
                // Step 1: ensure location permission
                await MainActor.run { wifiStatus = "Requesting permissions..." }
                await wifiConnector.ensureLocationPermission()

                // Step 2: record current SSID
                await MainActor.run { wifiStatus = "Reading current network..." }
                let originalSSID = await wifiConnector.currentSSID()

                // Step 3: connect to bulb AP
                await MainActor.run { wifiStatus = "Connecting to \(bulbSSID)..." }
                try await wifiConnector.connect(to: bulbSSID)

                // Step 4: verify we're on the bulb
                await MainActor.run { wifiStatus = "Verifying connection to \(bulbSSID)..." }
                try await wifiConnector.verifyConnected(to: bulbSSID)

                // Step 5: send SetAccessPoint packet via TLS
                await MainActor.run { wifiStatus = "Sending credentials to bulb..." }
                try await BulbProvisioner.provision(ssid: targetSSID, password: password)

                // Step 6: disconnect from bulb (auto-rejoins home network)
                await MainActor.run { wifiStatus = "Switching back to home network..." }
                wifiConnector.disconnect(from: bulbSSID)

                // Step 7: verify we're back on original
                if let original = originalSSID {
                    await MainActor.run { wifiStatus = "Verifying return to \(original)..." }
                    try await wifiConnector.verifyConnected(to: original)
                } else {
                    try await Task.sleep(nanoseconds: 3_000_000_000)
                }

                let returnedTo = await wifiConnector.currentSSID() ?? "unknown"

                await MainActor.run {
                    isConnecting = false
                    wifiStatus = nil
                    connectResult = .success(
                        "Provisioned \(bulbSSID) with \"\(targetSSID)\", returned to \(returnedTo)"
                    )
                }
            } catch {
                // Try to get back to home network on failure
                wifiConnector.disconnect(from: bulbSSID)
                let currentNet = await wifiConnector.currentSSID() ?? "unknown"
                await MainActor.run {
                    isConnecting = false
                    wifiStatus = nil
                    connectResult = .failure(
                        "\(error.localizedDescription) (currently on: \(currentNet))"
                    )
                }
            }
        }
    }
}
