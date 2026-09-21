import SwiftUI
import UIKit

enum CosmeticSlot: String, CaseIterable, Identifiable {
    case cap, bottle
    var id: String { rawValue }

    var title: String {
        switch self {
        case .cap: "Caps"
        case .bottle: "Bottles"
        }
    }
}

struct CosmeticItem: Identifiable, Equatable, Hashable {
    let id: String
    let slot: CosmeticSlot
    let name: String
    let hex: String
    /// Coins to buy it.
    let price: Int
    /// If set, this item is earned (not bought) by reaching this longest streak.
    let streakRequirement: Int?

    var color: Color { Color(hex: hex) }
    var displayName: String { "\(name) \(slot.rawValue)" }
    /// Everyone starts with these.
    var isStarter: Bool { price == 0 && streakRequirement == nil }
}

/// Every cap and bottle in the shop. Edit names, colors and prices here.
enum CosmeticCatalog {
    static let caps: [CosmeticItem] = [
        CosmeticItem(id: "cap.stone", slot: .cap, name: "Stone", hex: "#8E959E", price: 0, streakRequirement: nil),
        CosmeticItem(id: "cap.gold", slot: .cap, name: "Gold", hex: "#F5B82E", price: 20, streakRequirement: nil),
        CosmeticItem(id: "cap.ocean", slot: .cap, name: "Ocean", hex: "#1F5FA8", price: 15, streakRequirement: nil),
        CosmeticItem(id: "cap.coral", slot: .cap, name: "Coral", hex: "#E86A5C", price: 15, streakRequirement: nil),
        CosmeticItem(id: "cap.chrome", slot: .cap, name: "Chrome", hex: "#C7CED6", price: 30, streakRequirement: nil),
        CosmeticItem(id: "cap.violet", slot: .cap, name: "Violet", hex: "#6C4CE0", price: 0, streakRequirement: 7)
    ]

    static let bottles: [CosmeticItem] = [
        CosmeticItem(id: "bottle.clear", slot: .bottle, name: "Clear", hex: "#BDEBF7", price: 0, streakRequirement: nil),
        CosmeticItem(id: "bottle.frost", slot: .bottle, name: "Frost", hex: "#E4ECF2", price: 25, streakRequirement: nil),
        CosmeticItem(id: "bottle.midnight", slot: .bottle, name: "Midnight", hex: "#27405E", price: 35, streakRequirement: nil),
        CosmeticItem(id: "bottle.peach", slot: .bottle, name: "Peach", hex: "#FFD9BE", price: 35, streakRequirement: nil),
        CosmeticItem(id: "bottle.lilac", slot: .bottle, name: "Lilac", hex: "#DCD3FF", price: 35, streakRequirement: nil),
        CosmeticItem(id: "bottle.arctic", slot: .bottle, name: "Arctic", hex: "#CFF3FF", price: 0, streakRequirement: 30)
    ]

    static var all: [CosmeticItem] { caps + bottles }

    static func items(for slot: CosmeticSlot) -> [CosmeticItem] {
        switch slot {
        case .cap: caps
        case .bottle: bottles
        }
    }

    static func item(id: String) -> CosmeticItem? {
        all.first { $0.id == id }
    }
}

/// The colors the bottle is drawn with.
struct BottleStyle: Equatable {
    let cap: Color
    let capBand: Color
    let body: Color

    init(capHex: String, bottleHex: String) {
        cap = Color(hex: capHex)
        capBand = Color(hex: capHex, darkenedBy: 0.75)
        body = Color(hex: bottleHex)
    }

    init(cap: CosmeticItem?, bottle: CosmeticItem?) {
        self.init(
            capHex: cap?.hex ?? "#8E959E",
            bottleHex: bottle?.hex ?? "#BDEBF7"
        )
    }

    static let standard = BottleStyle(capHex: "#8E959E", bottleHex: "#BDEBF7")
}

extension Color {
    init(hex: String, darkenedBy factor: Double = 1) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let value = UInt64(cleaned, radix: 16) ?? 0
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self.init(red: r * factor, green: g * factor, blue: b * factor)
    }

    /// Water is always this blue, whatever bottle you pick.
    static let sipWater = Color(hex: "#3BB7DE")
    static let sipBubble = Color(hex: "#E6F8FD")
    static let sipGold = Color(hex: "#F5B82E")
    static let sipGoldDark = Color(hex: "#C98A12")
    /// Readable gold text in both light and dark mode.
    static let sipGoldText = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.96, green: 0.72, blue: 0.18, alpha: 1)
            : UIColor(red: 0.36, green: 0.24, blue: 0.0, alpha: 1)
    })
}
