import SwiftUI

struct WeekDayStatus: Identifiable, Equatable {
    let id: Date        // start of that day
    let letter: String
    let met: Bool
    let isToday: Bool
    let isFuture: Bool
}

/// Monday–Sunday drops: filled when you hit your goal, today circled.
struct WeekStripView: View {
    let days: [WeekDayStatus]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(days) { day in
                VStack(spacing: 5) {
                    ZStack {
                        if day.isToday {
                            Circle()
                                .stroke(Color.sipWater, lineWidth: 1.5)
                                .frame(width: 32, height: 32)
                        }
                        DropShape()
                            .stroke(Color.sipWater.opacity(day.isFuture ? 0.35 : 0.8),
                                    lineWidth: day.isToday ? 2 : 1.5)
                            .frame(width: 15, height: 19)
                        DropShape()
                            .fill(Color.sipWater)
                            .frame(width: 15, height: 19)
                            .scaleEffect(day.met ? 1 : 0.01, anchor: .bottom)
                            .opacity(day.met ? 1 : 0)
                    }
                    .frame(height: 34)
                    Text(day.letter)
                        .font(.caption2.weight(day.isToday ? .bold : .medium))
                        .foregroundStyle(day.isToday ? Color.primary : Color.secondary)
                }
                .frame(maxWidth: .infinity)
                .animation(.spring(response: 0.5, dampingFraction: 0.6), value: day.met)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityText(for: day))
            }
        }
    }

    private func accessibilityText(for day: WeekDayStatus) -> String {
        let name = day.id.formatted(.dateTime.weekday(.wide))
        if day.isFuture { return name }
        return "\(name)\(day.isToday ? ", today" : ""): \(day.met ? "goal met" : "goal not met")"
    }
}

struct DropShape: Shape {
    func path(in rect: CGRect) -> Path {
        let r = rect.width / 2
        let centerY = rect.maxY - r
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: centerY),
                       control: CGPoint(x: rect.maxX, y: rect.minY + (centerY - rect.minY) * 0.55))
        p.addArc(center: CGPoint(x: rect.midX, y: centerY), radius: r,
                 startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
        p.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.minY),
                       control: CGPoint(x: rect.minX, y: rect.minY + (centerY - rect.minY) * 0.55))
        p.closeSubpath()
        return p
    }
}
