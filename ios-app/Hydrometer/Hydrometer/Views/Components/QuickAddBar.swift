import SwiftUI

/// Manual logging for when the cap isn't in the loop.
struct QuickAddBar: View {
    let onAdd: (Double) -> Void
    private let amounts: [Double] = [4, 8, 12, 16]

    var body: some View {
        HStack(spacing: 10) {
            ForEach(amounts, id: \.self) { oz in
                Button { onAdd(oz) } label: {
                    Text("+\(Int(oz))")
                        .font(.headline.monospacedDigit())
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .tint(.sipOcean)
                .accessibilityLabel("Add \(Int(oz)) ounces")
            }
            Menu {
                ForEach([20.0, 24, 32], id: \.self) { oz in
                    Button("Add \(oz.ozText)") { onAdd(oz) }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .frame(minWidth: 36, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .tint(.sipOcean)
        }
    }
}
