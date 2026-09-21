import Foundation
import CoreBluetooth

/// GATT layout the cap firmware advertises. Generate your own UUIDs with `uuidgen`
/// and paste the same values into the ESP32 sketch.
enum SmartCapUUIDs {
    static var service: CBUUID { CBUUID(string: "5A1F0001-7C3B-4E2A-9D6B-2F8E4B1C0A01") }
    /// Notify characteristic carrying one JSON object per message.
    static var events: CBUUID { CBUUID(string: "5A1F0002-7C3B-4E2A-9D6B-2F8E4B1C0A01") }
    /// Standard Bluetooth SIG Battery Service / Battery Level (optional).
    static var batteryService: CBUUID { CBUUID(string: "180F") }
    static var batteryLevel: CBUUID { CBUUID(string: "2A19") }
}

/// The firmware's data contract:
///
/// ```json
/// { "volume": 450, "event": "drink", "amount": 100,
///   "dailyIntake": 300, "status": "upright", "timestamp": 1234567890 }
/// ```
///
/// - volume:      mL currently in the bottle (from the Hall sensor + float)
/// - event:       "drink" | "refill" | "idle"
/// - amount:      mL of that event
/// - dailyIntake: mL the device has counted since midnight
/// - status:      "upright" | "tilted" (IMU gate)
/// - timestamp:   epoch seconds
/// - battery:     optional 0–100, if you add it later
struct CapPayload: Codable, Equatable {
    var volume: Double?
    var event: String?
    var amount: Double?
    var dailyIntake: Double?
    var status: String?
    var timestamp: Double?
    var battery: Int?

    enum Kind: String {
        case drink, refill, idle, unknown
    }

    var kind: Kind {
        guard let event else { return .idle }
        return Kind(rawValue: event.lowercased()) ?? .unknown
    }

    var isTilted: Bool { status?.lowercased() == "tilted" }

    /// Dedupe key: the firmware may resend the same reading.
    var identity: String {
        "\(timestamp ?? 0)-\(event ?? "idle")-\(amount ?? 0)-\(volume ?? -1)"
    }

    var encoded: Data { (try? JSONEncoder().encode(self)) ?? Data() }
}

enum VolumeUnits {
    static let millilitersPerOunce = 29.5735

    static func ounces(fromMilliliters ml: Double) -> Double {
        (ml / millilitersPerOunce * 10).rounded() / 10
    }

    static func milliliters(fromOunces oz: Double) -> Double {
        (oz * millilitersPerOunce).rounded()
    }
}

/// Collects bytes from BLE notifications and hands back whole JSON objects.
/// Handles messages split across packets and newline-delimited streams.
struct JSONLineBuffer {
    private var buffer = Data()
    private let limit = 4096

    mutating func append(_ data: Data) -> [CapPayload] {
        buffer.append(data)
        if buffer.count > limit { buffer.removeAll() } // never grow forever on junk

        var payloads: [CapPayload] = []
        let decoder = JSONDecoder()

        // Newline-delimited messages first.
        while let newline = buffer.firstIndex(of: 0x0A) {
            let line = buffer[buffer.startIndex..<newline]
            buffer.removeSubrange(buffer.startIndex...newline)
            if let payload = try? decoder.decode(CapPayload.self, from: Data(line)) {
                payloads.append(payload)
            }
        }

        // Or a complete object with no newline after it.
        if payloads.isEmpty, !buffer.isEmpty,
           let payload = try? decoder.decode(CapPayload.self, from: buffer) {
            payloads.append(payload)
            buffer.removeAll()
        }
        return payloads
    }

    mutating func reset() { buffer.removeAll() }
}
