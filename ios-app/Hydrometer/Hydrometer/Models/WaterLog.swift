import Foundation
import SwiftData

@Model
final class WaterLog {
    var id: UUID
    /// Owning user's Apple ID. A plain string keeps #Predicate queries simple and reliable.
    var ownerID: String
    var timestamp: Date
    var amountOz: Double
    var sourceRaw: String

    var source: LogSource { LogSource(rawValue: sourceRaw) ?? .manual }

    init(ownerID: String, amountOz: Double, timestamp: Date = .now, source: LogSource = .manual) {
        self.id = UUID()
        self.ownerID = ownerID
        self.amountOz = amountOz
        self.timestamp = timestamp
        self.sourceRaw = source.rawValue
    }
}

enum LogSource: String, Codable {
    case manual, smartCap, simulator

    var label: String {
        switch self {
        case .manual: "Added by hand"
        case .smartCap: "Smart cap"
        case .simulator: "Simulated cap"
        }
    }

    var systemImage: String {
        switch self {
        case .manual: "hand.tap.fill"
        case .smartCap: "sensor.fill"
        case .simulator: "wand.and.stars"
        }
    }
}
