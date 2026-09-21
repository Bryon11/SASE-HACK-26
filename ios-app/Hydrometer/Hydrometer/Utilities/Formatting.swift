import SwiftUI

extension Double {
    /// 8 → "8 oz", 6.5 → "6.5 oz"
    var ozText: String {
        "\(formatted(.number.precision(.fractionLength(0...1)))) oz"
    }
}

extension Data {
    var hexString: String { map { String(format: "%02X", $0) }.joined(separator: " ") }
}

/// Hydrometer palette: deep-water navy, bright aqua, and mint for "over goal".
extension Color {
    static let sipDeep = Color(red: 0.03, green: 0.13, blue: 0.24)   // #08213D
    static let sipOcean = Color(red: 0.05, green: 0.40, blue: 0.75)  // #0D66BF
    static let sipAqua = Color(red: 0.25, green: 0.78, blue: 0.95)   // #40C7F2
    static let sipMint = Color(red: 0.36, green: 0.90, blue: 0.70)   // #5CE6B3
    static let sipEmber = Color(red: 1.00, green: 0.55, blue: 0.20)  // streak flame
}
