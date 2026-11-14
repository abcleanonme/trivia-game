import SwiftUI
import TriviaKit

/// End of round: points, answer strip, score breakdown, Sparks earned.
struct SummaryView: View {
    let session: GameSession
    /// Wallet balance after this round's Sparks were added.
    let balance: Int
    /// What the round earned beyond points (Daily bonus, level-ups, stamps).
    var rewards: RoundRewards? = nil
    /// nil hides Play again (the Daily is one try a day).
    let onPlayAgain: (() -> Void)?
    /// Shown after a friend match.
    var onRematch: (() -> Void)? = nil
    let onHome: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Flips once the Sparks count lands, for the bolt hop and confetti.
    @State private var sparksLanded = 0

    var body: some View {
        ScrollView {
            VStack(spacing: Space.l) {
                VStack(spacing: Space.xs) {
                    SectionLabel(headline)
                    CountingText(value: session.totalPoints, delay: 0.25, duration: 1.0)
                        .font(Theme.display(.largeTitle).weight(.heavy))
                        .scaleEffect(1.4)
                        .padding(.vertical, 8)
                        .foregroundStyle(Theme.ink)
                    Text("points · \(session.correctCount) of \(session.results.count) correct")
                        .font(.callout)
                        .foregroundStyle(Theme.muted)
                }
                .multilineTextAlignment(.center)
                .accessibilityElement(children: .combine)
                .staggeredAppear(0)

                answerStrip

                if let daily = rewards?.daily {
                    DailyShareSection(record: daily)
                }

                VStack(spacing: Space.s) {
                    let b = session.breakdown
                    row("Correct answers (\(session.correctCount))", b.base)
                    row("Speed bonus", b.speed, signed: true)
                    row("Streak bonus (best \(session.bestStreak))", b.streakBonus, signed: true)
                    if b.powerUpAdjustment != 0 {
                        row("Power-ups", b.powerUpAdjustment, signed: true)
                    }
                    Rectangle().fill(Theme.line).frame(height: 2)
                    row("Total", b.total).font(.headline)
                }
                .font(.subheadline)
                .foregroundStyle(Theme.ink)
                .padding(Theme.cardPadding)
                .card()
                .staggeredAppear(3, step: 0.12)

                HStack(spacing: 14) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: Theme.shadow, radius: 0, x: 1, y: 1)
                        .symbolEffect(.bounce, options: .nonRepeating, value: sparksLanded)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        CountingText(value: sparksEarned, delay: 1.1, duration: 0.7,
                                     prefix: "+", suffix: " Sparks",
                                     onFinish: { sparksLanded += 1 })
                            .font(Theme.display(.title2))
                        Text(sparksDetail)
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .foregroundStyle(Theme.onSpark)
                .padding(Theme.cardPadding)
                .card(fill: Theme.spark, drop: 5)
                .keyframeAnimator(initialValue: 1.0, trigger: sparksLanded) { view, scale in
                    view.scaleEffect(scale)
                } keyframes: { _ in
                    if reduceMotion {
                        LinearKeyframe(1, duration: 0.01)
                    } else {
                        SpringKeyframe(1.05, duration: 0.14, spring: .snappy)
                        SpringKeyframe(1, duration: 0.45, spring: .bouncy)
                    }
                }
                .accessibilityElement(children: .combine)
                .staggeredAppear(4, step: 0.12)

                if let rewards, !(rewards.levelUps.isEmpty && rewards.newStamps.isEmpty
                                  && rewards.unlocked.isEmpty && rewards.eventSparks == 0) {
                    RewardsCard(rewards: rewards)
                        .staggeredAppear(5, step: 0.12)
                }
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.top, Space.l)
            .padding(.bottom, Space.m)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .overlay {
            ConfettiBurst(trigger: sparksLanded, active: sparksEarned > 0)
                .ignoresSafeArea()
        }
        .safeAreaInset(edge: .bottom) {
            // One row: a small Home and a big primary action (Rematch or
            // Play again). Stacks when large text would squeeze them. The
            // Daily has no Play again, so Home goes full width.
            (typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: 10))
                : AnyLayout(HStackLayout(spacing: 10))) {
                Button(action: onHome) {
                    Label("Home", systemImage: "house.fill")
                        .font(.headline)
                        .padding(.horizontal, 18)
                        .frame(maxWidth: hasPrimary && !typeSize.isAccessibilitySize ? nil : .infinity,
                               minHeight: 52)
                }
                .buttonStyle(.chunky(fill: Theme.card, capsule: true))
                if let onRematch {
                    Button(action: onRematch) {
                        Label("Rematch", systemImage: "arrow.triangle.2.circlepath")
                            .font(.title3.bold())
                            .frame(maxWidth: .infinity, minHeight: 52)
                    }
                    .buttonStyle(.chunky(fill: Theme.accent, foreground: .white, capsule: true))
                } else if let onPlayAgain {
                    Button(action: onPlayAgain) {
                        Label("Play again", systemImage: "arrow.clockwise")
                            .font(.title3.bold())
                            .frame(maxWidth: .infinity, minHeight: 52)
                    }
                    .buttonStyle(.chunky(fill: Theme.accent, foreground: .white, capsule: true))
                }
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.vertical, Space.m)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
            .background(Theme.paper)
            .staggeredAppear(5, step: 0.12, distance: 30)
        }
        .background(Theme.paper)
    }

    private var sparksEarned: Int { rewards?.sparks ?? session.sparksEarned }

    private var hasPrimary: Bool { onRematch != nil || onPlayAgain != nil }

    private var headline: String {
        if let daily = rewards?.daily { return "Daily #\(daily.day.dailyNumber) complete" }
        switch session.mode {
        case .classic: return "Round complete"
        case .survival: return "Survived \(session.correctCount) questions"
        case .speed: return "Speed round: \(session.correctCount) right"
        }
    }

    private var sparksDetail: String {
        var text = "1 Spark per \(GameRules.pointsPerSpark) points"
        if let bonus = rewards?.bonusSparks, bonus > 0 { text += " + \(bonus) bonus" }
        return text + ". Balance \(balance)."
    }

    /// One pill per question, with a check or cross so it never relies on
    /// color alone. Long Survival and Speed rounds wrap onto more rows.
    private var answerStrip: some View {
        FlowLayout(spacing: 5) {
            ForEach(Array(session.results.enumerated()), id: \.offset) { i, r in
                Image(systemName: r.correct ? "checkmark" : "xmark")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 22)
                    .background(Capsule().fill(r.correct ? Theme.correct : Theme.wrong))
                    // Ticks in left to right, like a scoreboard.
                    .staggeredAppear(i + 4, step: 0.06, distance: 8)
            }
        }
        .frame(maxWidth: 26 * 10 + 5 * 9)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Answers: \(session.correctCount) correct, \(session.results.count - session.correctCount) wrong")
    }

    private func row(_ label: String, _ value: Int, signed: Bool = false) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(signed && value > 0 ? "+\(value.formatted())" : value.formatted()).bold()
        }
    }
}

#Preview {
    var s = GameSession(questions: Question.samples)
    for q in Question.samples {
        s.answer(q.correctIndex)
        s.advance()
    }
    return SummaryView(session: s, balance: 340, onPlayAgain: {}, onHome: {})
        .environment(PlayerStore.preview)
}
