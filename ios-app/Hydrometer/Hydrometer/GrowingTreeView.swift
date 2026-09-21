import SwiftUI

/// A tree drawn from a single 0–1 growth value. When `waterAmount` goes up,
/// the bottle tips and pours, droplets fall, and the tree gives a little bounce.
struct GrowingTreeView: View {
    let growth: Double
    /// Today's total — any increase triggers a pour.
    let waterAmount: Double
    var showsBottle = true
    /// Plays the pour once whenever the view appears (used on the Tree tab).
    var pourOnAppear = false
    /// Your bottle's cap and body colors, so the pouring bottle matches it.
    var bottleStyle: BottleStyle = .standard

    @State private var pourDate: Date = .distantPast
    @State private var bounce = false

    private let pourDuration: Double = 2.1

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            TimelineView(.animation) { context in
                let since = context.date.timeIntervalSince(pourDate)
                let pouring = since >= 0 && since < pourDuration

                ZStack {
                    ground(width: w, height: h)
                    if pouring { wetSpot(width: w, height: h, since: since) }
                    tree(width: w, height: h, pouring: pouring)
                    if showsBottle {
                        if pouring { stream(width: w, height: h, since: since) }
                        pourBottle(width: w, height: h, since: since)
                        if pouring { splash(width: w, height: h, since: since) }
                    }
                }
            }
        }
        .onChange(of: waterAmount) { oldValue, newValue in
            guard newValue > oldValue else { return }
            pour()
        }
        .task {
            guard pourOnAppear else { return }
            try? await Task.sleep(for: .milliseconds(350)) // let the page settle first
            guard !Task.isCancelled else { return }
            pour()
        }
        .accessibilityElement()
        .accessibilityLabel("Your tree, \(Int((growth * 100).rounded())) percent grown")
    }

    /// Tip the bottle, drop the water, bounce the tree.
    private func pour() {
        pourDate = .now
        withAnimation(.spring(response: 0.4, dampingFraction: 0.45).delay(0.75)) { bounce = true }
        Task {
            try? await Task.sleep(for: .milliseconds(1200))
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { bounce = false }
        }
    }

    // MARK: Pieces

    private func ground(width w: CGFloat, height h: CGFloat) -> some View {
        ZStack {
            Ellipse()
                .fill(Color(hex: "#C8A87C").opacity(0.55))
                .frame(width: w * 0.62, height: h * 0.09)
                .position(x: w / 2, y: h * 0.93)
            Ellipse()
                .fill(Color(hex: "#8D6E4B").opacity(0.35))
                .frame(width: w * 0.38, height: h * 0.05)
                .position(x: w / 2, y: h * 0.925)
        }
    }

    private func tree(width w: CGFloat, height h: CGFloat, pouring: Bool) -> some View {
        let base = CGPoint(x: w / 2, y: h * 0.9)
        let trunkHeight = h * (0.1 + 0.48 * growth)
        let trunkWidth = max(w * (0.03 + 0.07 * growth), 3)
        let canopyRadius = w * (0.09 + 0.26 * growth)
        let leafCount = 1 + Int(growth * 6)

        return ZStack {
            // Trunk
            Path { path in
                path.move(to: CGPoint(x: base.x - trunkWidth / 2, y: base.y))
                path.addQuadCurve(
                    to: CGPoint(x: base.x - trunkWidth * 0.25, y: base.y - trunkHeight),
                    control: CGPoint(x: base.x - trunkWidth * 0.9, y: base.y - trunkHeight * 0.5)
                )
                path.addLine(to: CGPoint(x: base.x + trunkWidth * 0.25, y: base.y - trunkHeight))
                path.addQuadCurve(
                    to: CGPoint(x: base.x + trunkWidth / 2, y: base.y),
                    control: CGPoint(x: base.x + trunkWidth * 0.9, y: base.y - trunkHeight * 0.5)
                )
                path.closeSubpath()
            }
            .fill(Color(hex: "#8A5A2B"))

            // Canopy
            ForEach(0..<leafCount, id: \.self) { i in
                let angle = Double(i) / Double(max(leafCount, 1)) * 2 * .pi
                let spread = canopyRadius * (growth < 0.15 ? 0.2 : 0.62)
                let x = base.x + CGFloat(cos(angle)) * spread
                let y = base.y - trunkHeight - CGFloat(sin(angle)) * spread * 0.55
                Circle()
                    .fill(Color(hex: i % 2 == 0 ? "#3E9B4F" : "#5ABF63"))
                    .frame(width: canopyRadius * 1.1, height: canopyRadius * 1.1)
                    .position(x: x, y: y)
            }
            Circle()
                .fill(Color(hex: "#4CAE58"))
                .frame(width: canopyRadius * 1.35, height: canopyRadius * 1.35)
                .position(x: base.x, y: base.y - trunkHeight - canopyRadius * 0.15)

            // Water-drop fruit once it's well grown
            if growth > 0.72 {
                ForEach(0..<3, id: \.self) { i in
                    let offsets: [CGSize] = [
                        CGSize(width: -canopyRadius * 0.55, height: -trunkHeight * 0.1),
                        CGSize(width: canopyRadius * 0.5, height: -trunkHeight * 0.02),
                        CGSize(width: canopyRadius * 0.05, height: -trunkHeight * 0.22)
                    ]
                    DropShape()
                        .fill(Color.sipWater)
                        .frame(width: canopyRadius * 0.24, height: canopyRadius * 0.3)
                        .position(x: base.x + offsets[i].width,
                                  y: base.y - trunkHeight + offsets[i].height)
                }
            }
        }
        .scaleEffect(bounce ? 1.06 : 1, anchor: .bottom)
        .animation(.spring(response: 0.5, dampingFraction: 0.6), value: growth)
    }

    // MARK: Pour

    private struct PourGeometry {
        let pivot: CGPoint      // bottom of the bottle
        let bodyWidth: CGFloat
        let bodyHeight: CGFloat
        let capHeight: CGFloat
        let soil: CGPoint       // where the water lands

        init(width w: CGFloat, height h: CGFloat) {
            pivot = CGPoint(x: w * 0.78, y: h * 0.36)
            bodyWidth = w * 0.085
            bodyHeight = w * 0.17
            capHeight = w * 0.032
            soil = CGPoint(x: w * 0.55, y: h * 0.885)
        }

        /// The bottle's mouth for a given tilt (degrees, negative = tipped left).
        func mouth(tilt: Double) -> CGPoint {
            let theta = tilt * .pi / 180
            let length = bodyHeight + capHeight
            return CGPoint(x: pivot.x + length * CGFloat(sin(theta)),
                           y: pivot.y - length * CGFloat(cos(theta)))
        }

        /// Direction water leaves the mouth.
        func axis(tilt: Double) -> CGPoint {
            let theta = tilt * .pi / 180
            return CGPoint(x: CGFloat(sin(theta)), y: CGFloat(-cos(theta)))
        }
    }

    private func smooth(_ x: Double) -> Double {
        let t = min(max(x, 0), 1)
        return t * t * (3 - 2 * t)
    }

    /// Rests slightly tipped, swings to 105° to pour, wobbles, then rights itself.
    private func tilt(since: Double) -> Double {
        let rest = -10.0, full = -105.0
        guard since >= 0, since < pourDuration else { return rest }
        if since < 0.45 { return rest + (full - rest) * smooth(since / 0.45) }
        if since < 1.6 { return full + sin(since * 10) * 2.5 }
        return full + (rest - full) * smooth((since - 1.6) / 0.45)
    }

    /// Water inside the bottle drops while it pours.
    private func bottleLevel(since: Double) -> Double {
        guard since >= 0, since < pourDuration else { return 0.72 }
        return 0.72 - 0.34 * smooth((since - 0.4) / 1.2)
    }

    private func pourBottle(width w: CGFloat, height h: CGFloat, since: Double) -> some View {
        let g = PourGeometry(width: w, height: h)
        let level = bottleLevel(since: since)

        return ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: g.bodyWidth * 0.32, style: .continuous)
                .fill(bottleStyle.body)
            RoundedRectangle(cornerRadius: g.bodyWidth * 0.24, style: .continuous)
                .fill(Color.sipWater)
                .frame(width: g.bodyWidth * 0.72, height: g.bodyHeight * 0.84 * level)
                .padding(.bottom, g.bodyWidth * 0.14)
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.white.opacity(0.55))
                .frame(width: g.bodyWidth * 0.12, height: g.bodyHeight * 0.45)
                .offset(x: -g.bodyWidth * 0.24, y: -g.bodyHeight * 0.3)
        }
        .frame(width: g.bodyWidth, height: g.bodyHeight)
        .overlay(alignment: .top) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: g.capHeight * 0.3, style: .continuous)
                    .fill(bottleStyle.cap)
                Rectangle()
                    .fill(bottleStyle.capBand)
                    .frame(height: g.capHeight * 0.3)
            }
            .frame(width: g.bodyWidth * 0.72, height: g.capHeight)
            .clipShape(RoundedRectangle(cornerRadius: g.capHeight * 0.3, style: .continuous))
            .offset(y: -g.capHeight + 1)
        }
        .rotationEffect(.degrees(tilt(since: since)), anchor: .bottom)
        .position(x: g.pivot.x, y: g.pivot.y - g.bodyHeight / 2)
        .shadow(color: .black.opacity(0.12), radius: 3, y: 2)
    }

    /// A curved stream from the mouth to the soil that flows in, then trails off.
    @ViewBuilder
    private func stream(width w: CGFloat, height h: CGFloat, since: Double) -> some View {
        let g = PourGeometry(width: w, height: h)
        let angle = tilt(since: since)
        let mouth = g.mouth(tilt: angle)
        let axis = g.axis(tilt: angle)
        let control = CGPoint(x: mouth.x + axis.x * w * 0.09, y: mouth.y + axis.y * w * 0.09 + h * 0.04)
        let head = smooth((since - 0.35) / 0.35)
        let tail = since > 1.5 ? smooth((since - 1.5) / 0.35) : 0

        if head > 0 && tail < 1 {
            let path = Path { p in
                p.move(to: mouth)
                p.addQuadCurve(to: g.soil, control: control)
            }
            path
                .trim(from: tail, to: head)
                .stroke(Color.sipWater, style: StrokeStyle(lineWidth: w * 0.022, lineCap: .round))
            path
                .trim(from: tail, to: head)
                .stroke(Color.white.opacity(0.45), style: StrokeStyle(lineWidth: w * 0.006, lineCap: .round))

            // Sparkles riding down the stream
            ForEach(0..<4, id: \.self) { i in
                let u = (since * 1.6 + Double(i) * 0.25).truncatingRemainder(dividingBy: 1)
                if u >= tail && u <= head {
                    let a = (1 - u) * (1 - u)
                    let b = 2 * (1 - u) * u
                    let c = u * u
                    Circle()
                        .fill(Color.sipBubble)
                        .frame(width: w * 0.012, height: w * 0.012)
                        .position(x: CGFloat(a) * mouth.x + CGFloat(b) * control.x + CGFloat(c) * g.soil.x,
                                  y: CGFloat(a) * mouth.y + CGFloat(b) * control.y + CGFloat(c) * g.soil.y)
                }
            }
        }
    }

    /// Droplets bounce off the soil once the stream arrives.
    @ViewBuilder
    private func splash(width w: CGFloat, height h: CGFloat, since: Double) -> some View {
        let g = PourGeometry(width: w, height: h)
        if since > 0.7 && since < 1.95 {
            ForEach(0..<5, id: \.self) { i in
                let t = (since - 0.7 - Double(i) * 0.12).truncatingRemainder(dividingBy: 0.5)
                if t > 0 {
                    let direction: CGFloat = i % 2 == 0 ? 1 : -1
                    let spread = CGFloat(0.02 + Double(i) * 0.008)
                    let x = g.soil.x + direction * w * spread * CGFloat(t / 0.5)
                    let y = g.soil.y - h * 0.06 * CGFloat(t / 0.5) + h * 0.14 * CGFloat(t * t)
                    Circle()
                        .fill(Color.sipWater)
                        .frame(width: w * 0.014, height: w * 0.014)
                        .position(x: x, y: y)
                        .opacity(1 - t / 0.5)
                }
            }
        }
    }

    /// The soil darkens where the water lands, then dries.
    private func wetSpot(width w: CGFloat, height h: CGFloat, since: Double) -> some View {
        let g = PourGeometry(width: w, height: h)
        let grow = smooth((since - 0.65) / 0.5)
        let fade = since > 1.7 ? smooth((since - 1.7) / 0.4) : 0
        return Ellipse()
            .fill(Color(hex: "#6B4A2B").opacity(0.35 * grow * (1 - fade)))
            .frame(width: w * 0.3 * grow, height: h * 0.04 * grow)
            .position(x: g.soil.x, y: g.soil.y + h * 0.01)
    }
}

/// Compact card for the home screen.
struct TreeCard: View {
    let lifetimeOunces: Double
    let todayTotal: Double
    var action: (() -> Void)? = nil

    private var growth: Double { TreeGrowth.growth(for: lifetimeOunces) }

    var body: some View {
        content
            .contentShape(RoundedRectangle(cornerRadius: 20))
            .onTapGesture { action?() }
    }

    private var content: some View {
        HStack(spacing: 14) {
                GrowingTreeView(growth: growth, waterAmount: todayTotal, showsBottle: false)
                    .frame(width: 76, height: 96)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text("Your tree · \(TreeGrowth.stageName(for: lifetimeOunces))")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    ProgressView(value: TreeGrowth.progressToNextStage(for: lifetimeOunces))
                        .tint(Color(hex: "#4CAE58"))
                    Text(caption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var caption: String {
        guard let remaining = TreeGrowth.ouncesToNextStage(for: lifetimeOunces),
              let next = TreeGrowth.nextStage(for: lifetimeOunces) else {
            return "Fully grown — \(lifetimeOunces.rounded().ozText) in total"
        }
        return "\(remaining.rounded().ozText) of water until \(next.name.lowercased())"
    }
}
