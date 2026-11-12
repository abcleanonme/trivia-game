import SwiftUI
import TriviaKit

/// End of round: points, answer strip, score breakdown, Sparks earned.
struct SummaryView: View {
    let session: GameSession
    /// Wallet balance after this round's Sparks were added.
    let balance: Int
    let onPlayAgain: () -> Void
    let onHome: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Flips once the Sparks count lands, for the bolt hop and confetti.
    @State private var sparksLanded = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 6) {
                    SectionLabel("Round complete")
                    CountingText(value: session.totalPoints, delay: 0.25, duration: 1.0)
                        .font(Theme.display(.largeTitle).weight(.heavy))
                        .scaleEffect(1.5)
                        .padding(.vertical, 10)
                        .foregroundStyle(Theme.ink)
                    Text("points · \(session.correctCount) of \(session.results.count) correct")
                        .font(.callout)
                        .foregroundStyle(Theme.muted)
                }
                .multilineTextAlignment(.center)
                .accessibilityElement(children: .combine)
                .staggeredAppear(0)

                answerStrip

                VStack(spacing: 12) {
                    let b = session.breakdown
                    row("Correct answers (\(session.correctCount) × \(GameRules.basePoints))", b.base)
                    row("Speed bonus", b.speed, signed: true)
                    row("Streak bonus (best \(session.bestStreak))", b.streakBonus, signed: true)
                    if b.powerUpAdjustment != 0 {
                        row("Power-ups", b.powerUpAdjustment, signed: true)
                    }
                    Rectangle().fill(Theme.line).frame(height: 2)
                    row("Total", b.total).font(.headline)
                }
                .font(.body)
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
                .card()
                .staggeredAppear(3, step: 0.12)

                HStack(spacing: 14) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: Theme.shadow, radius: 0, x: 1, y: 1)
                        .symbolEffect(.bounce, options: .nonRepeating, value: sparksLanded)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        CountingText(value: session.sparksEarned, delay: 1.1, duration: 0.7,
                                     prefix: "+", suffix: " Sparks",
                                     onFinish: { sparksLanded += 1 })
                            .font(Theme.display(.title2))
                        Text("1 Spark per \(GameRules.pointsPerSpark) points. Balance \(balance).")
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .foregroundStyle(Theme.onSpark)
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
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
            }
            .padding(.horizontal, 20)
            .padding(.top, 40)
            .padding(.bottom, 16)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .overlay {
            ConfettiBurst(trigger: sparksLanded, active: session.sparksEarned > 0)
                .ignoresSafeArea()
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 12) {
                Button(action: onPlayAgain) {
                    Text("Play again").font(.title3.bold()).frame(maxWidth: .infinity, minHeight: 56)
                }
                .buttonStyle(.chunky(fill: Theme.accent, foreground: .white, capsule: true))
                Button(action: onHome) {
                    Text("Home").font(.headline).frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(.chunky(fill: Theme.card, capsule: true))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
            .background(Theme.paper)
            .staggeredAppear(5, step: 0.12, distance: 30)
        }
        .background(Theme.paper)
    }

    private var answerStrip: some View {
        HStack(spacing: 6) {
            ForEach(Array(session.results.enumerated()), id: \.offset) { i, r in
                Capsule()
                    .fill(r.correct ? Theme.correct : Theme.wrong)
                    .frame(maxWidth: 26)
                    .frame(height: 10)
                    // Ticks in left to right, like a scoreboard.
                    .staggeredAppear(i + 4, step: 0.06, distance: 8)
            }
        }
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
}
