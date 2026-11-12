import SwiftUI
import TriviaKit

/// End of round: points, answer strip, score breakdown, Sparks earned.
struct SummaryView: View {
    let session: GameSession
    /// Wallet balance after this round's Sparks were added.
    let balance: Int
    let onPlayAgain: () -> Void
    let onHome: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 6) {
                    SectionLabel("Round complete")
                    Text(session.totalPoints, format: .number)
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

                HStack(spacing: 14) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 34, weight: .bold))
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
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
                .card(fill: Theme.spark, drop: 5)
                .accessibilityElement(children: .combine)
            }
            .padding(.horizontal, 20)
            .padding(.top, 40)
            .padding(.bottom, 16)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
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
        }
        .background(Theme.paper)
    }

    private var answerStrip: some View {
        HStack(spacing: 6) {
            ForEach(Array(session.results.enumerated()), id: \.offset) { _, r in
                Capsule()
                    .fill(r.correct ? Theme.correct : Theme.wrong)
                    .frame(maxWidth: 26)
                    .frame(height: 10)
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
