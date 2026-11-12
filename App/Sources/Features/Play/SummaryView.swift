import SwiftUI
import TriviaKit

/// End of round: points, answer strip, score breakdown, Sparks earned.
struct SummaryView: View {
    let session: GameSession
    /// Wallet balance after this round's Sparks were added.
    let balance: Int
    let onPlayAgain: () -> Void
    let onHome: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 4) {
                    SectionLabel("Round complete")
                    Text(session.totalPoints, format: .number)
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

                answerStrip

                VStack(spacing: 8) {
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
                .font(.subheadline)
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .card()

                HStack(spacing: 14) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: Theme.shadow, radius: 0, x: 1, y: 1)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("+\(session.sparksEarned) Sparks").font(Theme.display(.title2))
                        Text("1 Spark per \(GameRules.pointsPerSpark) points. Balance \(balance).")
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .foregroundStyle(Theme.onSpark)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .card(fill: Theme.spark, drop: 5)
                .accessibilityElement(children: .combine)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) {
            // One row: a small Home and a big Play again. Stacks when large
            // text would squeeze them.
            (typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: 10))
                : AnyLayout(HStackLayout(spacing: 10))) {
                Button(action: onHome) {
                    Label("Home", systemImage: "house.fill")
                        .font(.headline)
                        .padding(.horizontal, 18)
                        .frame(maxWidth: typeSize.isAccessibilitySize ? .infinity : nil, minHeight: 52)
                }
                .buttonStyle(.chunky(fill: Theme.card, capsule: true))
                Button(action: onPlayAgain) {
                    Label("Play again", systemImage: "arrow.clockwise")
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(.chunky(fill: Theme.accent, foreground: .white, capsule: true))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
            .background(Theme.paper)
        }
        .background(Theme.paper)
    }

    /// One dot per question, with a check or cross so it never relies on
    /// color alone.
    private var answerStrip: some View {
        HStack(spacing: 5) {
            ForEach(Array(session.results.enumerated()), id: \.offset) { _, r in
                Image(systemName: r.correct ? "checkmark" : "xmark")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(maxWidth: 26)
                    .frame(height: 22)
                    .background(Capsule().fill(r.correct ? Theme.correct : Theme.wrong))
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
