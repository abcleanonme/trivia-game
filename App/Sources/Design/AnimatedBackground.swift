import SwiftUI
import TriviaKit

/// The screen background for the equipped app theme: the theme's paper plus
/// a slow, low-contrast animation that gives the app some life.
///
/// Battery: drawn with one `Canvas` capped at 20 fps, built from cheap
/// shapes and gradients (no blur), and paused while the app is in the
/// background. It shows a still frame instead of animating when Reduce
/// Motion or Low Power Mode is on, or when the player turns animated
/// backgrounds off in Settings.
struct ThemeBackground: View {
    /// Shows this palette instead of the equipped one (shop previews).
    var palette: ThemePalette? = nil
    /// false always shows the still frame (small swatches).
    var animated = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("animatedBackgrounds") private var animationsOn = true
    @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled

    var body: some View {
        let palette = self.palette ?? ThemeManager.shared.palette
        let paused = !animated || reduceMotion || lowPower || !animationsOn || scenePhase != .active
        ZStack {
            palette.paper
            TimelineView(.animation(minimumInterval: 1.0 / 20, paused: paused)) { timeline in
                Canvas(rendersAsynchronously: true) { context, size in
                    // A fixed time gives the still frame a pleasant layout.
                    let t = paused ? 12 : timeline.date.timeIntervalSinceReferenceDate
                    BackgroundPainter(palette: palette, time: t).draw(in: &context, size: size)
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
            lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
    }
}

extension View {
    /// Puts the equipped theme's (animated) background behind a screen.
    /// Use in place of `.background(Theme.paper)` on full screens.
    func themeBackground(_ palette: ThemePalette? = nil) -> some View {
        background { ThemeBackground(palette: palette) }
    }
}

/// Draws one frame of a theme's background. Pure function of time and size,
/// so the still frame (Reduce Motion) and previews are deterministic.
struct BackgroundPainter {
    let palette: ThemePalette
    let time: TimeInterval

    private var colors: [Color] { palette.motionColors.isEmpty ? [palette.accent] : palette.motionColors }
    private func color(_ i: Int) -> Color { colors[i % colors.count] }
    private var strength: Double { palette.intensity }

    func draw(in context: inout GraphicsContext, size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        switch palette.motion {
        case .drift: drift(&context, size)
        case .bubbles: bubbles(&context, size)
        case .waves: waves(&context, size)
        case .stars: stars(&context, size)
        case .confetti: confetti(&context, size)
        case .grid: grid(&context, size)
        }
    }

    /// Stable pseudo-random value in 0..<1 for item `i`, channel `k`.
    private func rand(_ i: Int, _ k: Int) -> Double {
        let x = sin(Double(i) * 12.9898 + Double(k) * 78.233) * 43758.5453
        return x - x.rounded(.down)
    }

    private func frac(_ x: Double) -> Double { x - x.rounded(.down) }

    // MARK: Styles

    /// Soft color glows slowly orbiting the screen (Classic).
    private func drift(_ c: inout GraphicsContext, _ s: CGSize) {
        let r = max(s.width, s.height) * 0.55
        for i in 0..<3 {
            let speed = 0.035 + Double(i) * 0.012
            let a = time * speed + Double(i) * 2.1
            let center = CGPoint(x: s.width * (0.5 + 0.38 * cos(a)),
                                 y: s.height * (0.45 + 0.35 * sin(a * 1.3 + Double(i))))
            glow(&c, at: center, radius: r, color: color(i), opacity: 0.16 * strength)
        }
    }

    /// Bubbles rising and wobbling (Mint Fizz).
    private func bubbles(_ c: inout GraphicsContext, _ s: CGSize) {
        glow(&c, at: CGPoint(x: s.width * 0.15, y: s.height * 0.9), radius: s.width * 0.8,
             color: color(0), opacity: 0.12 * strength)
        for i in 0..<16 {
            let radius = 6 + rand(i, 1) * 20
            let speed = 0.025 + rand(i, 2) * 0.03
            let travel = s.height + radius * 4
            let y = s.height + radius * 2 - frac(time * speed + rand(i, 3)) * travel
            let x = s.width * rand(i, 4) + sin(time * 0.6 + Double(i)) * 10
            let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
            c.stroke(Circle().path(in: rect), with: .color(color(i).opacity(0.32 * strength)), lineWidth: 1.5)
        }
    }

    /// Layered waves rolling along the bottom (Sunset).
    private func waves(_ c: inout GraphicsContext, _ s: CGSize) {
        glow(&c, at: CGPoint(x: s.width * 0.75, y: s.height * 0.12), radius: s.width * 0.7,
             color: color(1), opacity: 0.22 * strength)
        for layer in 0..<3 {
            let base = s.height * (0.72 + Double(layer) * 0.08)
            let amp = 14.0 - Double(layer) * 3
            let len = s.width / (1.1 + Double(layer) * 0.4)
            let phase = time * (0.25 + Double(layer) * 0.1) + Double(layer)
            var p = Path()
            p.move(to: CGPoint(x: 0, y: s.height))
            for x in stride(from: CGFloat(0), through: s.width, by: 8) {
                p.addLine(to: CGPoint(x: x, y: base + sin(x / len * .pi * 2 + phase) * amp))
            }
            p.addLine(to: CGPoint(x: s.width, y: s.height))
            p.closeSubpath()
            c.fill(p, with: .color(color(layer == 1 ? 2 : 0).opacity((0.14 + Double(layer) * 0.04) * strength)))
        }
    }

    /// Twinkling stars and a faint moon glow (Midnight).
    private func stars(_ c: inout GraphicsContext, _ s: CGSize) {
        glow(&c, at: CGPoint(x: s.width * 0.8, y: s.height * 0.15), radius: s.width * 0.6,
             color: color(2), opacity: 0.18 * strength)
        for i in 0..<60 {
            let size = 1 + rand(i, 1) * 2.2
            let twinkle = 0.5 + 0.5 * sin(time * (0.6 + rand(i, 2) * 1.4) + rand(i, 3) * 6.28)
            // Very slow sideways drift so the sky feels alive.
            let x = frac(rand(i, 4) + time * 0.002) * s.width
            let y = rand(i, 5) * s.height
            let rect = CGRect(x: x, y: y, width: size, height: size)
            c.fill(Circle().path(in: rect), with: .color(color(i % 7 == 0 ? 1 : 0).opacity((0.25 + 0.6 * twinkle) * strength)))
        }
    }

    /// Slowly falling confetti (Confetti).
    private func confetti(_ c: inout GraphicsContext, _ s: CGSize) {
        for i in 0..<22 {
            let speed = 0.02 + rand(i, 1) * 0.025
            let y = -20 + frac(time * speed + rand(i, 2)) * (s.height + 40)
            let x = s.width * rand(i, 3) + sin(time * 0.5 + Double(i)) * 14
            let w = 6 + rand(i, 4) * 6
            var piece = c
            piece.translateBy(x: x, y: y)
            piece.rotate(by: .radians(time * (0.4 + rand(i, 5)) + Double(i)))
            let rect = CGRect(x: -w / 2, y: -w / 4, width: w, height: w / 2)
            piece.fill(RoundedRectangle(cornerRadius: 1.5).path(in: rect),
                       with: .color(color(i).opacity(0.38 * strength)))
        }
    }

    /// A retro grid scrolling toward a glowing sun (Neon Arcade).
    private func grid(_ c: inout GraphicsContext, _ s: CGSize) {
        let horizon = s.height * 0.62
        let center = CGPoint(x: s.width / 2, y: horizon)
        glow(&c, at: center, radius: s.width * 0.6, color: color(0), opacity: 0.22 * strength)
        let line = GraphicsContext.Shading.color(color(1).opacity(0.28 * strength))
        // Horizontal lines, spaced by perspective, moving toward the viewer.
        for i in 0..<10 {
            let z = frac(Double(i) / 10 + time * 0.04)
            let y = horizon + (s.height - horizon) * z * z
            var p = Path()
            p.move(to: CGPoint(x: 0, y: y))
            p.addLine(to: CGPoint(x: s.width, y: y))
            c.stroke(p, with: line, lineWidth: 1)
        }
        // Lines converging on the vanishing point.
        for i in -6...6 {
            var p = Path()
            p.move(to: center)
            p.addLine(to: CGPoint(x: s.width / 2 + Double(i) * s.width * 0.22, y: s.height))
            c.stroke(p, with: line, lineWidth: 1)
        }
    }

    private func glow(_ c: inout GraphicsContext, at center: CGPoint, radius: CGFloat, color: Color, opacity: Double) {
        let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        c.fill(Circle().path(in: rect),
               with: .radialGradient(Gradient(colors: [color.opacity(opacity), color.opacity(0)]),
                                     center: center, startRadius: 0, endRadius: radius))
    }
}

#Preview {
    ScrollView {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))]) {
            ForEach(ThemePalette.all) { palette in
                ThemeBackground(palette: palette)
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
            }
        }
        .padding()
    }
}
