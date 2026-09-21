import SwiftUI
import AuthenticationServices

/// Sign-in screen: the bottle is the hero, three swipeable intro slides explain
/// the app, and the sign-in buttons stay pinned at the bottom the whole time.
/// When `isDiving` turns on, the cap twists off and the screen zooms into the bottle.
struct SignInView: View {
    var isDiving: Bool = false

    @Environment(AuthService.self) private var auth
    @State private var page = 0
    @State private var capFrame: CGRect = .zero
    @State private var diveStarted = false

    private let slides: [(title: String, subtitle: String)] = [
        ("Every sip, counted", "Twist your smart cap and Hydrometer logs it for you."),
        ("Build a streak", "Hit your goal each day and watch your week fill up."),
        ("Earn coins", "Spend them on new caps and bottle colors.")
    ]

    private var heroProgress: Double { [0.55, 0.8, 1.0][page] }

    private var heroStyle: BottleStyle {
        page == 2
            ? BottleStyle(capHex: "#F5B82E", bottleHex: "#BDEBF7")
            : .standard
    }

    var body: some View {
        GeometryReader { geo in
            let origin = geo.frame(in: .global).origin
            ZStack {
                SignInBackground()

                VStack(spacing: 0) {
                    Text("Hydrometer")
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.top, 12)

                    hero
                        .frame(height: 330)

                    captions
                    pageDots
                        .padding(.top, 6)

                    Spacer(minLength: 16)

                    signInPanel
                        .opacity(isDiving ? 0 : 1)
                        .animation(.easeOut(duration: 0.2), value: isDiving)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .scaleEffect(isDiving ? 7 : 1, anchor: zoomAnchor(size: geo.size, origin: origin))
                .animation(.easeIn(duration: 0.75).delay(0.3), value: isDiving)
            }
        }
        .onPreferenceChange(CapFrameKey.self) { frame in
            // Freeze the zoom target before the cap lifts off.
            if !diveStarted { capFrame = frame }
        }
        .onChange(of: isDiving) { _, diving in diveStarted = diving }
        .task { await autoAdvance() }
    }

    // MARK: Hero

    private var hero: some View {
        ZStack {
            WeekPreviewDrops(active: page == 1)
                .offset(y: -150)
                .opacity(page == 1 ? 1 : 0)

            WaterBottleView(progress: heroProgress, isCapOpen: isDiving, style: heroStyle,
                            width: 116, height: 232, reportsCapFrame: true)
                .offset(y: 12)

            streakBadge
                .offset(x: 92, y: 96)
                .scaleEffect(page == 1 ? 1 : 0.4)
                .opacity(page == 1 ? 1 : 0)

            ForEach(0..<3, id: \.self) { i in
                let spots: [CGSize] = [CGSize(width: -92, height: -70),
                                       CGSize(width: 94, height: -104),
                                       CGSize(width: -84, height: 70)]
                CoinView(size: i == 1 ? 34 : 28)
                    .offset(spots[i])
                    .scaleEffect(page == 2 ? 1 : 0.1)
                    .opacity(page == 2 ? 1 : 0)
                    .animation(.spring(response: 0.45, dampingFraction: 0.55).delay(Double(i) * 0.12), value: page)
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: page)
    }

    private var streakBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "flame.fill")
                .foregroundStyle(LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom))
                .symbolEffect(.bounce, value: page == 1)
            Text("4 days")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .environment(\.colorScheme, .dark)
    }

    // MARK: Captions

    private var captions: some View {
        TabView(selection: $page) {
            ForEach(slides.indices, id: \.self) { i in
                VStack(spacing: 8) {
                    Text(slides[i].title)
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundStyle(.white)
                    Text(slides[i].subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 12)
                .tag(i)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: 92)
    }

    private var pageDots: some View {
        HStack(spacing: 8) {
            ForEach(slides.indices, id: \.self) { i in
                Button {
                    withAnimation(.easeInOut) { page = i }
                } label: {
                    Capsule()
                        .fill(Color.white.opacity(i == page ? 1 : 0.35))
                        .frame(width: i == page ? 22 : 8, height: 8)
                        .padding(.vertical, 12) // bigger tap target
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Slide \(i + 1) of \(slides.count)")
            }
        }
        .animation(.snappy, value: page)
    }

    // MARK: Sign in

    private var signInPanel: some View {
        VStack(spacing: 12) {
            SignInWithAppleButton(.signIn) { request in
                auth.configure(request)
            } onCompletion: { result in
                auth.handle(result)
            }
            .signInWithAppleButtonStyle(.white)
            .frame(height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            #if DEBUG
            Button("Continue in demo mode") { auth.signInAsDemo() }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.85))
                .frame(minHeight: 44)
            #endif

            if let error = auth.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .environment(\.colorScheme, .dark)
    }

    // MARK: Helpers

    /// Zoom toward the bottle's neck so it feels like diving in.
    private func zoomAnchor(size: CGSize, origin: CGPoint) -> UnitPoint {
        guard capFrame != .zero, size.width > 0, size.height > 0 else { return UnitPoint(x: 0.5, y: 0.35) }
        return UnitPoint(x: (capFrame.midX - origin.x) / size.width,
                         y: (capFrame.maxY + 6 - origin.y) / size.height)
    }

    private func autoAdvance() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(4.5))
            guard !Task.isCancelled, !diveStarted else { continue }
            withAnimation(.easeInOut(duration: 0.5)) { page = (page + 1) % slides.count }
        }
    }
}

// MARK: - Slide 2 accent

/// Seven drops that fill in one by one while the streak slide is showing.
private struct WeekPreviewDrops: View {
    let active: Bool
    @State private var filled = 0

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<7, id: \.self) { i in
                ZStack {
                    DropShape()
                        .stroke(Color.sipWater.opacity(0.7), lineWidth: 1.5)
                    DropShape()
                        .fill(Color.sipWater)
                        .scaleEffect(i < filled ? 1 : 0.01, anchor: .bottom)
                        .opacity(i < filled ? 1 : 0)
                }
                .frame(width: 14, height: 18)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: filled)
        .task(id: active) {
            filled = 0
            guard active else { return }
            for step in 1...4 {
                try? await Task.sleep(for: .milliseconds(220))
                guard !Task.isCancelled else { return }
                filled = step
            }
        }
    }
}

// MARK: - Background

/// Deep-ocean gradient with slowly rolling waves and drifting bubbles.
private struct SignInBackground: View {
    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    LinearGradient(colors: [Color(hex: "#061528"), Color.sipDeep, Color(hex: "#0F3A63")],
                                   startPoint: .top, endPoint: .bottom)

                    ForEach(0..<10, id: \.self) { i in
                        let seed = Double(i)
                        let height = Double(geo.size.height)
                        let speed = 18 + (seed * 7).truncatingRemainder(dividingBy: 20)
                        let y = height - (t * speed + seed * 131).truncatingRemainder(dividingBy: height)
                        let x = Double(geo.size.width) * (seed * 0.113 + 0.04).truncatingRemainder(dividingBy: 1)
                            + sin(t * 0.8 + seed) * 8
                        let size = CGFloat(4 + (seed * 1.9).truncatingRemainder(dividingBy: 8))
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .frame(width: size, height: size)
                            .position(x: x, y: y)
                    }

                    WaveShape(level: 0.55, amplitude: 10, phase: t * 0.8, tilt: 0, frequency: 1.1)
                        .fill(Color(hex: "#123E66"))
                        .frame(height: 220)
                    WaveShape(level: 0.4, amplitude: 8, phase: t * 1.2 + 2, tilt: 0, frequency: 1.4)
                        .fill(Color(hex: "#174D7E"))
                        .frame(height: 220)
                    WaveShape(level: 0.25, amplitude: 6, phase: t * 1.6 + 4, tilt: 0, frequency: 1.7)
                        .fill(Color(hex: "#1A5A8E"))
                        .frame(height: 220)
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

// MARK: - Water curtain

/// The full-screen water used by the dive transition. It covers the screen while
/// the app swaps views, then slides down (`drained`) to reveal what's underneath.
struct WaterCurtainView: View {
    let drained: Bool

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                ZStack {
                    // Level above 1 keeps the whole screen covered; the wavy top edge
                    // only shows once the curtain starts draining.
                    WaveShape(level: 1.03, amplitude: 10, phase: t * 3, tilt: 0, frequency: 1.3)
                        .fill(Color.sipWater)

                    // Light rays
                    Rectangle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 26, height: geo.size.height * 0.7)
                        .rotationEffect(.degrees(12))
                        .position(x: geo.size.width * 0.3, y: geo.size.height * 0.3)
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 18, height: geo.size.height * 0.6)
                        .rotationEffect(.degrees(-8))
                        .position(x: geo.size.width * 0.68, y: geo.size.height * 0.28)

                    // Bubbles rushing upward
                    ForEach(0..<16, id: \.self) { i in
                        let seed = Double(i)
                        let height = Double(geo.size.height)
                        let speed = 220 + (seed * 37).truncatingRemainder(dividingBy: 160)
                        let y = height - (t * speed + seed * 97).truncatingRemainder(dividingBy: height)
                        let x = Double(geo.size.width) * (seed * 0.137 + 0.05).truncatingRemainder(dividingBy: 1)
                            + sin(t * 2 + seed) * 6
                        let size = CGFloat(6 + (seed * 1.7).truncatingRemainder(dividingBy: 10))
                        Circle()
                            .fill(Color.sipBubble.opacity(0.8))
                            .frame(width: size, height: size)
                            .position(x: x, y: y)
                    }
                }
            }
            .offset(y: drained ? geo.size.height + 60 : 0)
        }
        .ignoresSafeArea()
        .allowsHitTesting(!drained)
        .accessibilityHidden(true)
    }
}
