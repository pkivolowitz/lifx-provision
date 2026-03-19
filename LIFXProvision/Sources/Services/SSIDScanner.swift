// Copyright (c) 2026 Perry Kivolowitz — MIT License (see LICENSE)
/// Extracts "LIFX Bulb-*" SSIDs from a screenshot of Settings → WiFi
/// using Vision framework (VNRecognizeTextRequest).

import UIKit
import Vision

enum SSIDScanner {

    /// Result of scanning: matched SSIDs plus all raw OCR text for debugging.
    struct ScanResult {
        let ssids: [String]
        let rawText: [String]
    }

    /// Scans a UIImage for text matching "LIFX Bulb-" prefix.
    /// Returns matched SSIDs and all raw OCR lines.
    static func scan(image: UIImage) async throws -> ScanResult {
        guard let cgImage = image.cgImage else {
            return ScanResult(ssids: [], rawText: [])
        }

        let recognized = try await recognizeText(in: cgImage)
        let ssids = filterBulbSSIDs(from: recognized)
        return ScanResult(ssids: ssids, rawText: recognized)
    }

    // MARK: - Private

    private static func recognizeText(in cgImage: CGImage) async throws -> [String] {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let strings = (request.results as? [VNRecognizedTextObservation])?.compactMap { observation in
                    observation.topCandidates(1).first?.string
                } ?? []

                continuation.resume(returning: strings)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// Filters OCR results for LIFX bulb SSIDs.
    /// SSID format: "LIFX <model> <3 hex octets>" with spaces.
    /// e.g., "LIFX A19 D073D5"
    /// Vision splits on spaces, so "LIFX", model, and octets may each
    /// be separate observations. We find "LIFX", then gather fragments
    /// until we hit the 6-char hex suffix (3 octets).
    private static func filterBulbSSIDs(from strings: [String]) -> [String] {
        var seen = Set<String>()
        var results: [String] = []
        var consumed = Set<Int>()

        for (i, text) in strings.enumerated() {
            if consumed.contains(i) { continue }
            let trimmed = text.trimmingCharacters(in: .whitespaces)

            // Case 1: full SSID in one observation ("LIFX A19 D073D5")
            if trimmed.hasPrefix("LIFX ") && endsWithHexOctets(trimmed) {
                if !seen.contains(trimmed) {
                    seen.insert(trimmed)
                    results.append(trimmed)
                }
                continue
            }

            // Case 2: starts with "LIFX" — gather fragments
            guard trimmed == "LIFX" || trimmed.hasPrefix("LIFX ") else { continue }

            // If "LIFX <partial>" already has hex octets at the end, we're done
            if trimmed.hasPrefix("LIFX ") && endsWithHexOctets(trimmed) {
                continue // already handled above
            }

            var parts = [trimmed]
            consumed.insert(i)

            for j in (i + 1)..<min(i + 6, strings.count) {
                if consumed.contains(j) { continue }
                let next = strings[j].trimmingCharacters(in: .whitespaces)
                if next.isEmpty { continue }

                parts.append(next)
                consumed.insert(j)

                let candidate = parts.joined(separator: " ")
                if endsWithHexOctets(candidate) {
                    if !seen.contains(candidate) {
                        seen.insert(candidate)
                        results.append(candidate)
                    }
                    break
                }
            }
        }

        return results
    }

    /// Checks if the string ends with 6 hex characters (3 octets).
    /// The octets may be a standalone word at the end, e.g., "LIFX A19 D073D5".
    private static func endsWithHexOctets(_ text: String) -> Bool {
        let words = text.split(separator: " ")
        guard let last = words.last else { return false }
        // 3 octets = 6 hex characters
        if last.count == 6 && last.allSatisfy({ $0.isHexDigit }) {
            return true
        }
        // Some SSIDs might use uppercase/mixed — just check hex validity
        // Also handle 4-char suffixes in case some models use fewer octets
        if last.count >= 4 && last.count <= 8 && last.allSatisfy({ $0.isHexDigit }) {
            return true
        }
        return false
    }
}
