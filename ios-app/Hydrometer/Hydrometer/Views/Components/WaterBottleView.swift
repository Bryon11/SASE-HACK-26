import SwiftUI

// MARK: - Dashboard card

/// Bottle on the left, numbers on the right, bonus mini bottles underneath.
struct HydrationBottleCard: View {
    let total: Double
    let goal: Double
    let progress: Double
    let paceMessage: String
    /// "finished at 4:12 PM, 2 hr faster than usual" — optional.
    var finishLine: String? = nil
    let isCapOpen: Bool
    let style: BottleStyle

    private var bonusOunces: Double { max(total - goal, 0) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 22) {
                WaterBottleView(progress: progress, isCapOpen: isCapOpen, style: style, reportsCapFrame: true)
                stats
            }
            if bonusOunces > 0 {
                BonusBottlesRow(bonusOunces: bonusOunces, style: style)
                    .transition(.opacity)
            }
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .animation(.snappy, value: isCapOpen)
        .animation(.snappy, value: bonusOunces > 0)
    }

    private var stats: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(total.formatted(.number.precision(.fractionLength(0...1))))
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText(value: total))
                .animation(.snappy, value: total)
            Text("of \(goal.ozText)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Divider().padding(.vertical, 6)

            if progress >= 1 {
                Label("Goal reached", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(Color.sipOcean)
            } else {
                Text("\(max(goal - total, 0).ozText) left")
                    .font(.headline)
            }
            Text(paceMessage)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let finishLine {
                Text(finishLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if isCapOpen {
                Label("Cap open", systemImage: "arrow.up.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.sipEmber)
                    .padding(.top, 4)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Bonus mini bottles

/// One mini bottle per extra 8 oz past the goal; the next one fills as you drink.
struct BonusBottlesRow: View {
    let bonusOunces: Double
    let style: BottleStyle

    static let ouncesPerBottle = 8.0
    static let maxShown = 6

    var body: some View {
        let full = Int(bonusOunces / Self.ouncesPerBottle)
        let partial = (bonusOunces - Double(full) * Self.ouncesPerBottle) / Self.ouncesPerBottle
        let shownFull = min(full, Self.maxShown)
        let showPartial = full < Self.maxShown && partial > 0.01
        let hiddenCount = full - shownFull

        HStack(alignment: .bottom, spacing: 8) {
            ForEach(0..<shownFull, id: \.self) { _ in
                MiniBottleView(fill: 1, style: style)
                    .transition(.scale(scale: 0.2, anchor: .bottom).combined(with: .opacity))
            }
            if showPartial {
                MiniBottleView(fill: partial, style: style)
                    .transition(.scale(scale: 0.2, anchor: .bottom).combined(with: .opacity))
            }
            if hiddenCount > 0 {
                Text("+\(hiddenCount)")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.sipWater.opacity(0.18), in: Capsule())
            }
            Spacer(minLength: 0)
            Text("+\(bonusOunces.ozText) bonus")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.sipOcean)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.55), value: shownFull)
        .animation(.spring(response: 0.4, dampingFraction: 0.55), value: showPartial)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(bonusOunces.ozText) past your goal")
    }
}

struct MiniBottleView: View {
    let fill: Double
    let style: BottleStyle

    var body: some View {
        VStack(spacing: -1) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(style.cap)
                .frame(width: 16, height: 7)
                .zIndex(1)
            ZStack {
                BottleShape().fill(style.body)
                GeometryReader { geo in
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        Rectangle()
                            .fill(Color.sipWater)
                            .frame(height: geo.size.height * min(max(fill, 0), 1) * 0.94)
                    }
                }
                .clipShape(BottleShape())
                .padding(3)
            }
            .frame(width: 22, height: 38)
        }
        .animation(.easeOut(duration: 0.6), value: fill)
    }
}

// MARK: - Bottle

/// Reports where the cap is on screen, so coins can shoot out of it.
struct CapFrameKey: PreferenceKey {
    static let defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next != .zero { value = next }
    }
}

/// Slim bottle whose water follows your progress. The surface waves, sloshes when
/// a sip lands, bubbles drift up, and the cap twists off when the cap opens.
struct WaterBottleView: View {
    /// Fraction of the daily goal. The bottle stays full above 1.
    let progress: Double
    let isCapOpen: Bool
    let style: BottleStyle
    var width: CGFloat = 104
    var height: CGFloat = 220
    var reportsCapFrame = false
    /// Draws the float sensor: a metal rod down the middle with a ring that
    /// rides the water surface, like the real cap's level float.
    var showsFloat = false

    @State private var fromLevel: Double = 0
    @State private var toLevel: Double = 0
    @State private var changeDate: Date = .distantPast
    @State private var sloshDate: Date = .distantPast

    var body: some View {
        VStack(spacing: -height * 0.018) {
            TwistCapView(isOpen: isCapOpen, style: style)
                .frame(width: width * 0.7, height: height * 0.13)
                .background {
                    if reportsCapFrame {
                        GeometryReader { geo in
                            Color.clear.preference(key: CapFrameKey.self, value: geo.frame(in: .global))
                        }
                    }
                }
                .zIndex(1)

            ZStack {
                BottleShape()
                    .fill(style.body)

                TimelineView(.animation) { context in
                    GeometryReader { geo in
                        water(at: context.date, size: geo.size)
                    }
                }
                .clipShape(BottleShape())
                .padding(width * 0.075)

                // Glass highlight and base line, drawn over the water like the reference art.
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.55))
                    .frame(width: width * 0.065, height: height * 0.4)
                    .offset(x: -width * 0.32, y: -height * 0.06)
                Capsule()
                    .fill(Color.white.opacity(0.7))
                    .frame(width: width * 0.6, height: 2)
                    .offset(y: height * 0.455)
            }
            .frame(width: width, height: height)
        }
        .onAppear {
            fromLevel = 0
            toLevel = clamped(progress)
            changeDate = .now
            sloshDate = .now
        }
        .onChange(of: progress) { oldValue, newValue in
            let now = Date.now
            fromLevel = displayedLevel(at: now)
            toLevel = clamped(newValue)
            changeDate = now
            if newValue > oldValue { sloshDate = now }
        }
        .accessibilityElement()
        .accessibilityLabel("Water bottle")
        .accessibilityValue("\(Int((progress * 100).rounded())) percent of daily goal")
    }

    @ViewBuilder
    private func water(at date: Date, size: CGSize) -> some View {
        let level: Double = displayedLevel(at: date)
        let fill: Double = level * 0.94
        let since: Double = max(date.timeIntervalSince(sloshDate), 0)
        let decay: Double = exp(-since * 1.3)
        let calm: Double = min(level * 8, 1)
        let amplitude: Double = (2.0 + 9 * decay) * calm
        let tilt: Double = sin(since * 7) * 14 * decay * calm
        let time: Double = date.timeIntervalSinceReferenceDate
        let phase: Double = time * 2.2
        let surfaceY: Double = Double(size.height) * (1 - fill)

        ZStack {
            WaveShape(level: fill, amplitude: amplitude * 0.8, phase: phase * 0.8 + 2,
                      tilt: -tilt * 0.7, frequency: 1.3)
                .fill(Color.sipWater.opacity(0.45))
            WaveShape(level: fill, amplitude: amplitude, phase: phase,
                      tilt: tilt, frequency: 1.0)
                .fill(Color.sipWater)
            if showsFloat {
                floatSensor(size: size, surfaceY: surfaceY, amplitude: amplitude, phase: phase, tilt: tilt)
            }

            ForEach(Self.bubbles) { bubble in
                if let point = bubble.position(time: time, size: size, surfaceY: surfaceY) {
                    Circle()
                        .fill(Color.sipBubble)
                        .frame(width: bubble.radius * 2, height: bubble.radius * 2)
                        .position(point)
                }
            }
        }
    }

    /// The rod stays put; the ring floats on the surface and bobs with the waves.
    @ViewBuilder
    private func floatSensor(size: CGSize, surfaceY: Double, amplitude: Double, phase: Double, tilt: Double) -> some View {
        let ringWidth: Double = Double(size.width) * 0.62
        let ringHeight: Double = ringWidth * 0.34
        let bob: Double = sin(phase) * amplitude * 0.45
        let y: Double = min(max(surfaceY + bob, ringHeight), Double(size.height) - ringHeight * 0.8)

        // Metal rod
        Capsule()
            .fill(LinearGradient(colors: [Color(white: 0.85), Color(white: 0.45), Color(white: 0.75)],
                                 startPoint: .leading, endPoint: .trailing))
            .frame(width: 4, height: size.height)
            .position(x: size.width / 2, y: size.height / 2)

        // Float ring
        ZStack {
            Ellipse()
                .fill(Color.black.opacity(0.12))
                .frame(width: ringWidth, height: ringHeight)
                .offset(y: 2)
            Ellipse()
                .stroke(LinearGradient(colors: [Color(white: 0.95), Color(white: 0.6)],
                                       startPoint: .top, endPoint: .bottom),
                        lineWidth: max(ringHeight * 0.32, 3))
                .frame(width: ringWidth, height: ringHeight)
        }
        .rotationEffect(.degrees(tilt * 0.25))
        .position(x: size.width / 2, y: y)
    }

    private func displayedLevel(at date: Date) -> Double {
        let t: Double = min(max(date.timeIntervalSince(changeDate), 0), 1)
        let eased: Double = 1 - pow(1 - t, 3)
        return fromLevel + (toLevel - fromLevel) * eased
    }

    private func clamped(_ value: Double) -> Double { min(max(value, 0), 1) }

    private static let bubbles: [Bubble] = [
        Bubble(id: 0, x: 0.30, speed: 16, radius: 3.5, offset: 0.10),
        Bubble(id: 1, x: 0.68, speed: 11, radius: 2.5, offset: 0.45),
        Bubble(id: 2, x: 0.45, speed: 20, radius: 2.0, offset: 0.75),
        Bubble(id: 3, x: 0.78, speed: 14, radius: 3.0, offset: 0.25),
        Bubble(id: 4, x: 0.22, speed: 9, radius: 2.0, offset: 0.60),
        Bubble(id: 5, x: 0.58, speed: 17, radius: 2.5, offset: 0.90)
    ]
}

private struct Bubble: Identifiable {
    let id: Int
    let x: Double       // 0...1 across the bottle
    let speed: Double   // points per second
    let radius: CGFloat
    let offset: Double  // 0...1 starting phase

    /// Rises from the bottom and disappears at the water surface.
    func position(time: Double, size: CGSize, surfaceY: Double) -> CGPoint? {
        let h = Double(size.height)
        guard h > 0 else { return nil }
        let travel = (time * speed + offset * h).truncatingRemainder(dividingBy: h)
        let y = h - travel
        guard y > surfaceY + 8 else { return nil }
        let wobble = sin(time * 1.6 + offset * 6) * 3
        return CGPoint(x: x * Double(size.width) + wobble, y: y)
    }
}

// MARK: - Shapes

/// Tall, slim bottle with softly rounded shoulders.
struct BottleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let neckInset = rect.width * 0.13
        let shoulder = rect.height * 0.08
        let corner = rect.width * 0.2

        var p = Path()
        p.move(to: CGPoint(x: rect.minX + neckInset, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - neckInset, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + shoulder),
                       control: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - corner))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - corner, y: rect.maxY),
                       control: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + corner, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - corner),
                       control: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + shoulder))
        p.addQuadCurve(to: CGPoint(x: rect.minX + neckInset, y: rect.minY),
                       control: CGPoint(x: rect.minX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

struct WaveShape: Shape {
    var level: Double
    var amplitude: Double
    var phase: Double
    var tilt: Double
    var frequency: Double

    func path(in rect: CGRect) -> Path {
        let minX = Double(rect.minX)
        let maxX = Double(rect.maxX)
        let maxY = Double(rect.maxY)
        let width = Double(rect.width)
        let baseY = maxY - Double(rect.height) * level

        var path = Path()
        path.move(to: CGPoint(x: minX, y: maxY))
        let steps = 48
        for i in 0...steps {
            let rel = Double(i) / Double(steps)
            let x = minX + width * rel
            let wave = sin(rel * .pi * 2 * frequency + phase) * amplitude
            let y = baseY + wave + (rel - 0.5) * tilt
            path.addLine(to: CGPoint(x: x, y: y))
        }
        path.addLine(to: CGPoint(x: maxX, y: maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Cap

/// Screw cap with grip ridges. Opening slides the ridges (a twist),
/// then lifts and tips the cap off; closing reverses it.
struct TwistCapView: View {
    let isOpen: Bool
    let style: BottleStyle
    @State private var twist: CGFloat = 0
    @State private var lifted = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            capBody(width: w, height: h)
        }
        .rotationEffect(.degrees(lifted ? -16 : 0), anchor: .bottomLeading)
        .offset(x: lifted ? 10 : 0, y: lifted ? -20 : 0)
        .shadow(color: .black.opacity(lifted ? 0.2 : 0), radius: 5, y: 3)
        .onAppear { lifted = isOpen }
        .onChange(of: isOpen) { _, open in
            if open {
                withAnimation(.easeInOut(duration: 0.4)) { twist -= 3 }
                withAnimation(.spring(response: 0.35, dampingFraction: 0.6).delay(0.3)) { lifted = true }
            } else {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { lifted = false }
                withAnimation(.easeInOut(duration: 0.4).delay(0.2)) { twist += 3 }
            }
        }
        .accessibilityHidden(true)
    }

    private func capBody(width w: CGFloat, height h: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: h * 0.18, style: .continuous)
                .fill(style.cap)
            Rectangle()
                .fill(style.capBand)
                .frame(height: h * 0.24)
            HStack(spacing: 6) {
                ForEach(0..<18, id: \.self) { _ in
                    Capsule()
                        .fill(Color.white.opacity(0.35))
                        .frame(width: 2.5, height: h * 0.4)
                }
            }
            .offset(x: twist * 8.5, y: -h * 0.3) // 8.5 = ridge + gap, so steps line up
        }
        .frame(width: w, height: h)
        .clipShape(RoundedRectangle(cornerRadius: h * 0.18, style: .continuous))
    }
}
