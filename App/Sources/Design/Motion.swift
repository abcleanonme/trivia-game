import SwiftUI

/// Shared animation vocabulary. Every effect here checks Reduce Motion
/// itself, so call sites never have to: movement (slides, shakes, bursts,
/// count-ups) becomes a short crossfade or the final state.
enum Motion {
    /// Snappy, slightly bouncy: answer reveals, badges, pops.
    static let pop = Animation.spring(response: 0.35, dampingFraction: 0.6)
    /// Smooth settle for layout changes and bars sliding in.
    static let settle = Animation.spring(response: 0.45, dampingFraction: 0.85)
    /// What every effect falls back to under Reduce Motion.
    static let fade = Animation.easeInOut(duration: 0.2)

    static func choose(_ animation: Animation, reduce: Bool) -> Animation {
        reduce ? fade : animation
    }
}

extension AnyTransition {
    /// Slides in from an edge and fades; a plain fade under Reduce Motion.
    static func motion(_ edge: Edge, reduce: Bool) -> AnyTransition {
        reduce ? .opacity : .move(edge: edge).combined(with: .opacity)
    }

    /// Grows in from slightly smaller; a plain fade under Reduce Motion.
    static func pop(reduce: Bool) -> AnyTransition {
        reduce ? .opacity : .scale(scale: 0.92).combined(with: .opacity)
    }
}

// MARK: - Staggered entrance

/// Fades a view in (and nudges it up) a beat after it appears, so a list
/// of items arrives one after another instead of all at once.
private struct StaggeredAppear: ViewModifier {
    let index: Int
    var step: Double = 0.05
    var distance: CGFloat = 18

    @Environment(\.accessibilityReduceMotion) private var reduce
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown || reduce ? 0 : distance)
            .onAppear {
                let animation = Motion.choose(Motion.settle, reduce: reduce)
                    .delay(reduce ? 0 : Double(index) * step)
                withAnimation(animation) { shown = true }
            }
    }
}

extension View {
    func staggeredAppear(_ index: Int, step: Double = 0.05, distance: CGFloat = 18) -> some View {
        modifier(StaggeredAppear(index: index, step: step, distance: distance))
    }
}

// MARK: - Answer reveal

/// Scale and sideways offset driven by keyframes.
struct RevealFrame {
    var scale: CGFloat = 1
    var x: CGFloat = 0
}

/// Pops a correct answer and shakes a wrong one when `outcome` changes.
/// Under Reduce Motion nothing moves; the color change carries it.
private struct RevealEffect: ViewModifier {
    /// true = correct, false = wrong, nil = not revealed.
    let outcome: Bool?

    @Environment(\.accessibilityReduceMotion) private var reduce

    func body(content: Content) -> some View {
        content.keyframeAnimator(initialValue: RevealFrame(), trigger: outcome) { view, frame in
            view.scaleEffect(frame.scale).offset(x: frame.x)
        } keyframes: { _ in
            KeyframeTrack(\.scale) {
                if outcome == true && !reduce {
                    SpringKeyframe(1.07, duration: 0.16, spring: .snappy)
                    SpringKeyframe(1, duration: 0.4, spring: .bouncy)
                } else {
                    LinearKeyframe(1, duration: 0.01)
                }
            }
            KeyframeTrack(\.x) {
                if outcome == false && !reduce {
                    for dx in [-10.0, 9, -7, 5, -3, 0] {
                        CubicKeyframe(dx, duration: 0.06)
                    }
                } else {
                    LinearKeyframe(0, duration: 0.01)
                }
            }
        }
    }
}

extension View {
    func revealEffect(_ outcome: Bool?) -> some View {
        modifier(RevealEffect(outcome: outcome))
    }
}

// MARK: - Confetti

/// A one-shot burst of confetti from both bottom corners. Fires each time
/// `trigger` changes while `active` is true. Draws nothing under Reduce
/// Motion. Never takes touches or shows up to VoiceOver.
struct ConfettiBurst: View {
    let trigger: Int
    var active: Bool = true
    /// Bigger bursts for streak milestones.
    var intensity: Double = 1

    @Environment(\.accessibilityReduceMotion) private var reduce
    @State private var startedAt: Date?

    private static let duration: Double = 1.6
    private static let particles: [Particle] = {
        var rng = SeededRandom(seed: 7)
        return (0..<70).map { i in Particle(rng: &rng, fromLeft: i.isMultiple(of: 2)) }
    }()

    var body: some View {
        TimelineView(.animation(paused: startedAt == nil)) { timeline in
            Canvas { ctx, size in
                guard let startedAt else { return }
                let t = timeline.date.timeIntervalSince(startedAt)
                guard t >= 0, t < Self.duration else { return }
                let count = Int(Double(Self.particles.count) * min(max(intensity, 0.3), 1))
                for p in Self.particles.prefix(count) {
                    p.draw(in: &ctx, size: size, t: t, life: Self.duration)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: trigger) {
            guard active, !reduce else { return }
            startedAt = .now
        }
        .task(id: startedAt) {
            guard startedAt != nil else { return }
            try? await Task.sleep(for: .seconds(Self.duration))
            startedAt = nil
        }
    }

    private struct Particle {
        let fromLeft: Bool
        let angle: Double      // radians from straight up, toward the middle
        let speed: Double      // fraction of screen height per second
        let spin: Double
        let size: CGSize
        let color: Color
        let circle: Bool

        init(rng: inout SeededRandom, fromLeft: Bool) {
            self.fromLeft = fromLeft
            angle = rng.next(in: 0.15...0.75)
            speed = rng.next(in: 0.9...1.55)
            spin = rng.next(in: -9...9)
            size = CGSize(width: rng.next(in: 6...10), height: rng.next(in: 9...15))
            let palette = [Theme.accent, Theme.spark, Theme.correct, Theme.wrong, Color(light: 0xE04F9F, dark: 0xF06BB3)]
            color = palette[Int(rng.next(in: 0..<Double(palette.count)))]
            circle = rng.next(in: 0...1) < 0.25
        }

        func draw(in ctx: inout GraphicsContext, size canvas: CGSize, t: Double, life: Double) {
            let h = canvas.height
            let gravity = 1.9 * h
            let dir: Double = fromLeft ? 1 : -1
            let vx = sin(angle) * speed * h * dir * 0.55
            let vy = -cos(angle) * speed * h
            let x = (fromLeft ? 0 : canvas.width) + vx * t
            let y = h + vy * t + 0.5 * gravity * t * t
            let fadeStart = life * 0.65
            let alpha = t < fadeStart ? 1 : max(0, 1 - (t - fadeStart) / (life - fadeStart))

            var c = ctx
            c.opacity = alpha
            c.translateBy(x: x, y: y)
            c.rotate(by: .radians(spin * t))
            // A cheap 3D flutter: squash the width as it "turns".
            c.scaleBy(x: cos(spin * t * 0.7), y: 1)
            let rect = CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height)
            let shape = circle ? Path(ellipseIn: rect.insetBy(dx: 0, dy: (size.height - size.width) / 2))
                               : Path(roundedRect: rect, cornerRadius: 2)
            c.fill(shape, with: .color(color))
        }
    }
}

/// Small deterministic generator so the confetti looks the same every time
/// and costs nothing to set up.
struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed &* 0x9E37_79B9_7F4A_7C15 | 1 }

    mutating func nextUInt() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }

    mutating func next(in range: ClosedRange<Double>) -> Double {
        range.lowerBound + Double(nextUInt() % 10_000) / 10_000 * (range.upperBound - range.lowerBound)
    }

    mutating func next(in range: Range<Double>) -> Double {
        range.lowerBound + Double(nextUInt() % 10_000) / 10_001 * (range.upperBound - range.lowerBound)
    }
}

// MARK: - Counting numbers

/// Counts from zero up to `value` after `delay`, ticking with a rolling
/// digit transition. Shows the final number right away under Reduce Motion
/// and to VoiceOver.
struct CountingText: View {
    let value: Int
    var delay: Double = 0
    var duration: Double = 0.9
    var prefix: String = ""
    var suffix: String = ""
    /// Called once the count lands on `value`.
    var onFinish: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduce
    @State private var shown: Int?

    var body: some View {
        Text("\(prefix)\((shown ?? value).formatted())\(suffix)")
            .monospacedDigit()
            .contentTransition(.numericText(value: Double(shown ?? value)))
            .accessibilityLabel("\(prefix)\(value.formatted())\(suffix)")
            .task(id: value) { await run() }
    }

    private func run() async {
        guard !reduce, value > 0 else {
            shown = value
            onFinish()
            return
        }
        shown = 0
        try? await Task.sleep(for: .seconds(delay))
        let steps = min(value, 24)
        for step in 1...steps {
            guard !Task.isCancelled else { return }
            // Ease out: big jumps first, then settle onto the number.
            let progress = 1 - pow(1 - Double(step) / Double(steps), 3)
            withAnimation(.snappy(duration: 0.12)) {
                shown = Int((Double(value) * progress).rounded())
            }
            try? await Task.sleep(for: .seconds(duration / Double(steps)))
        }
        shown = value
        onFinish()
    }
}

// MARK: - Floating callout

/// A short label ("+10s", "×2") that rises and fades out. Under Reduce
/// Motion it fades in place.
struct FloatingCallout: View {
    let text: String
    var color: Color = Theme.accent

    @Environment(\.accessibilityReduceMotion) private var reduce
    @State private var gone = false

    var body: some View {
        Text(text)
            .font(Theme.display(.headline))
            .foregroundStyle(color)
            .fixedSize()
            .offset(y: gone && !reduce ? -28 : 0)
            .opacity(gone ? 0 : 1)
            .scaleEffect(gone && !reduce ? 1.15 : 1)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear {
                withAnimation(.easeOut(duration: reduce ? 0.6 : 0.9).delay(0.15)) { gone = true }
            }
    }
}
