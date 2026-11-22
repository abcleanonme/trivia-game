import SwiftUI
import TriviaKit

/// One round from first question to summary. Owns the session and drives
/// its clock; the child views only read it and send actions.
struct GameView: View {
    let request: RoundRequest
    let relaxed: Bool

    @Environment(PlayerStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var current: RoundRequest
    @State private var session: GameSession?
    @State private var rewards: RoundRewards?
    @State private var alreadyPlayed = false
    /// Bumped on Play again so the quiz screen arrives fresh.
    @State private var round = 0

    init(request: RoundRequest, relaxed: Bool) {
        self.request = request
        self.relaxed = relaxed
        _current = State(initialValue: request)
    }

    var body: some View {
        Group {
            if let session {
                if session.phase == .finished {
                    summary(session)
                        .transition(.pop(reduce: reduceMotion))
                } else {
                    quiz(session)
                        .id(round)
                        .transition(.motion(.trailing, reduce: reduceMotion))
                }
            } else if alreadyPlayed {
                ContentUnavailableView {
                    Label("Already played today", systemImage: "calendar.badge.checkmark")
                } description: {
                    Text("The Daily is one try a day. A new one starts at midnight.")
                } actions: {
                    Button("Home") { dismiss() }
                        .buttonStyle(.chunky(fill: Theme.card, capsule: true))
                }
            }
        }
        .animation(Motion.choose(Motion.settle, reduce: reduceMotion), value: session?.phase == .finished)
        .animation(Motion.choose(Motion.settle, reduce: reduceMotion), value: round)
        .themeBackground()
        .onAppear { if session == nil { start() } }
        .onChange(of: session?.phase == .finished) { _, finished in
            if finished, let session { rewards = store.finish(session, for: current) }
        }
        .task {
            await runRoundClock(isActive: { scenePhase == .active }, tick: { session?.tick(by: $0) })
        }
    }

    private func summary(_ session: GameSession) -> SummaryView {
        let again: (() -> Void)? = current.isDaily ? nil : { playAgain() }
        return SummaryView(session: session,
                           balance: store.wallet.sparks,
                           rewards: rewards,
                           onPlayAgain: again,
                           onHome: { dismiss() })
    }

    private func quiz(_ session: GameSession) -> QuizView {
        let store = store
        let report: (Question, QuestionReport.Reason) -> Void = { q, reason in store.report(q, reason: reason) }
        return QuizView(session: session,
                        stock: { store.wallet.count(of: $0) },
                        onAnswer: { self.session?.answer($0) },
                        onPowerUp: { usePowerUp($0) },
                        onNext: { self.session?.advance() },
                        onQuit: { quit() },
                        onReport: report,
                        quitMessage: quitMessage)
    }

    private var quitMessage: String {
        current.isDaily
            ? "This is your only try at today's Daily. Leaving now keeps the score you have, and the day won't count toward your streak."
            : "You won't earn Sparks for this round. Power-ups you used are spent."
    }

    private func start() {
        rewards = nil
        session = store.newSession(for: current, relaxed: relaxed)
        alreadyPlayed = session == nil
        round += 1
        #if DEBUG
        // Screenshot helper: launch with `-autoplaySummary` to jump straight
        // to the results screen (answers alternate right and wrong).
        if ProcessInfo.processInfo.arguments.contains("-autoplaySummary"), var s = session {
            var i = 0
            while let q = s.currentQuestion {
                s.answer(i % 3 == 2 ? (q.correctIndex + 1) % q.choices.count : q.correctIndex)
                s.advance()
                i += 1
            }
            session = s
        }
        #endif
    }

    private func playAgain() {
        current = RoundRequest(kind: current.kind)
        start()
    }

    private func quit() {
        // Correct answers still count toward mastery, and the Daily keeps
        // the attempt.
        if let session, !session.results.isEmpty || current.isDaily {
            store.finish(session, for: current, finished: false)
        }
        dismiss()
    }

    private func usePowerUp(_ powerUp: PowerUp) {
        guard var s = session else { return }
        if store.use(powerUp, in: &s) { session = s }
    }
}

#Preview {
    GameView(request: .classic(), relaxed: false)
        .environment(PlayerStore.preview)
}
