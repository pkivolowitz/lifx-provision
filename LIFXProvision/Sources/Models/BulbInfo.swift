// Copyright (c) 2026 Perry Kivolowitz — MIT License (see LICENSE)
/// Model representing a discovered LIFX bulb in AP mode.

import Foundation

struct BulbInfo: Identifiable {
    let id: UUID = UUID()
    let ssid: String

    /// Status of provisioning for this bulb.
    var status: ProvisionStatus = .pending
}

enum ProvisionStatus {
    case pending
    case connecting
    case provisioning
    case verifying
    case success
    case failed(String)
}
